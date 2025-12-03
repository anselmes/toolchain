# Build SOCFPGA

## ATF (ARM Trusted Framework)

```shell
make clean && rm -rf build
make HOSTCC=clang \
    CC="clang -target aarch64-linux-gnu" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    PLAT=agilex5 \
    TARGET_SOC=AGILEX5 \
    GENERATE_HPS_ENABLE=1 \
    SOCFPGA_SDRAM_CONFIG=1 \
    HANDOFF="$HANDOFF_DIR" \
    ENABLE_PLAT_COMPAT=1 \
    CFLAGS="-Wno-error=unused-function -Wno-error=asm-operand-widths" \
    bl31
```

## U-Boot

```shell
make mrproper

export CROSS_COMPILE=aarch64-linux-gnu-
export HOSTCC=clang
export CC="clang -target aarch64-linux-gnu"

make HOSTCC=$HOSTCC CC=$CC socfpga_agilex5_defconfig

./scripts/config --enable CMD_BOOTEFI
./scripts/config --enable EFI_LOADER
./scripts/config --enable EFI_SECURE_BOOT

make HOSTCC=$HOSTCC CC=$CC olddefconfig
make HOSTCC=$HOSTCC CC=$CC -j $(nproc)

# Artifacts

cp -f spl/u-boot-spl-dtb.hex build/agilex5/uboot-socfpga-aarch64.hex
cp -f u-boot.itb build/agilex5/uboot-socfpga-aarch64.itb

# Boot script

mkimage -T script -A arm64 -O linux -C none -d modules/config/uboot/boot.txt build/agilex5/boot.scr
```

## Linux

```shell
make mrproper

export ARCH=arm64
export CC="clang -target aarch64-linux-gnu"
export CONFIG=defconfig
export CROSS_COMPILE=aarch64-linux-gnu-
export HOSTCC=clang
export KDEB_PKGVERSION=6.12.33
export LLVM=1

make ARCH=$ARCH HOSTCC=$HOSTCC LLVM=$LLVM CC=$CC rustavailable
make ARCH=$ARCH HOSTCC=$HOSTCC LLVM=$LLVM CC=$CC ${CONFIG}

# Rust
./scripts/config --enable RUST

# Base cgroup framework
./scripts/config --enable CGROUPS
./scripts/config --enable CGROUP_SCHED
./scripts/config --enable FAIR_GROUP_SCHED
./scripts/config --enable CFS_BANDWIDTH
./scripts/config --enable RT_GROUP_SCHED

# Controllers
./scripts/config --enable CPUSETS
./scripts/config --enable CGROUP_PIDS
./scripts/config --enable CGROUP_FREEZER
./scripts/config --enable CGROUP_DEVICE
./scripts/config --enable CGROUP_CPUACCT

# Memory / IO cgroups
./scripts/config --enable MEMCG
./scripts/config --enable MEMCG_SWAP
./scripts/config --enable MEMCG_KMEM
./scripts/config --enable BLK_CGROUP
./scripts/config --enable CGROUP_WRITEBACK

# BPF / perf in cgroups (optional but useful)
./scripts/config --enable CGROUP_BPF
./scripts/config --enable CGROUP_PERF

# cgroup v2 filesystem
./scripts/config --enable CGROUP2

# UEFI
./scripts/config --enable EFI_STUB
./scripts/config --enable EFIVAR_FS

# CAPS
./scripts/config --enable EXT4_FS_POSIX_ACL
./scripts/config --enable EXT4_FS_SECURITY
./scripts/config --enable SECURITY_FILE_CAPABILITIES

# Version string
./scripts/config --set-str LOCALVERSION "-socfpga-lts"

# Build

make ARCH=$ARCH HOSTCC=$HOSTCC LLVM=$LLVM CC=$CC olddefconfig
make ARCH=$ARCH HOSTCC=$HOSTCC LLVM=$LLVM CC=$CC -j"$(nproc)" modules dtbs
fakeroot make ARCH=$ARCH HOSTCC=$HOSTCC LLVM=$LLVM CC=$CC -j"$(nproc)" DPKG_FLAGS=-d bindeb-pkg

# Artifacts

cp -f ../*.deb build/agilex5/deb/
cp -f arch/arm64/boot/dts/altera/socfpga_*.dtb build/agilex5/dtb/
cp -f arch/arm64/boot/dts/intel/socfpga_*.dtb build/agilex5/dtb/
cp -f vmlinux build/agilex5/linux-socfpga-aarch64
```

## SOCFPGA

```shell

export ARCH=aarch64
export BOARD=DE25_Nano
export TARGET=agilex5

# Generate cmake project

niosv-app -b=modules/bsp/$TARGET -a=firmware/$TARGET -s=firmware/src/main.c

# Build

cmake -G Ninja -B fimrware/$TARGET/build -S firmware/$TARGET
cmake --build fimrware/$TARGET/build

# HPS

quartus_pfg -c output_files/socfpga.sof output_files/socfpga+hps.sof -o hps_path=uboot-socfpga-aarch64.hex
quartus_pfg -c output_files/socfpga+hps.sof output_files/socfpga.jic -o device=MT25QU128 -o flash_loader=A5EB013BB23B -o mode=ASX4

# Flash QSP
quartus_pgm -c 1 -o "pvi;socfpga.jic"

# Erase QSPI
quartus_pgm -m jtag -c 1 -o "ri;socfpga.jic"

# Artifacts

cp -f firmware/$TARGET/build/${TARGET}.elf build/$TARGET/fw-socfpga-$ARCH
cp -f firmware/$TARGET/build/ocram.hex ghrd/${BOARD}_GHRD/
cp -f ghrd/${BOARD}_GHRD/output_files/socfpga.rbf build/$TARGET/fpga/socfpga.rbf
# cp -f ghrd/${BOARD}_GHRD/fpga.dtbo build/$TARGET/fpga/socfpga.dtbo
# cp -f ghrd/${BOARD}_GHRD/soc_system.dtb build/$TARGET/dtb/socfpga_${TARGET}_$(echo ${BOARD} | tr '[:upper:]' '[:lower:]')_soc.dtb
```

## Ubuntu

```shell
# Mounts

[ -d "${mnt}/dev" ]   || sudo -E mkdir -m 0755 "${mnt}/dev"
[ -d "${mnt}/root" ]  || sudo -E mkdir -m 0700 "${mnt}/root"

[ -d "${mnt}/sys" ]   || sudo -E mkdir "${mnt}/sys"
[ -d "${mnt}/proc" ]  || sudo -E mkdir "${mnt}/proc"
[ -d "${mnt}/tmp" ]   || sudo -E mkdir "${mnt}/tmp"

sudo -E mkdir -p "${mnt}/var/lock"

mountpoint -q "${mnt}/sys"  || sudo -E mount -t sysfs   -o nodev,noexec,nosuid  sysfs  "${mnt}/sys"
mountpoint -q "${mnt}/proc" || sudo -E mount -t proc    -o nodev,noexec,nosuid  proc   "${mnt}/proc"

mountpoint -q "${mnt}/dev"  || sudo -E mount -t devtmpfs -o nosuid,mode=0755    udev  "${mnt}/dev"

[ ! -h "${mnt}/dev/fd" ]      && sudo -E ln -s "/proc/self/fd"    "${mnt}/dev/fd"
[ ! -h "${mnt}/dev/stdin" ]   && sudo -E ln -s "/proc/self/fd/0"  "${mnt}/dev/stdin"
[ ! -h "${mnt}/dev/stdout" ]  && sudo -E ln -s "/proc/self/fd/1"  "${mnt}/dev/stdout"
[ ! -h "${mnt}/dev/stderr" ]  && sudo -E ln -s "/proc/self/fd/2"  "${mnt}/dev/stderr"

mountpoint -q "${mnt}/dev/pts" || {
  [ -d "${mnt}/dev/pts" ] || sudo -E mkdir "${mnt}/dev/pts"
  sudo -E mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts "${mnt}/dev/pts"
}

mountpoint -q "${mnt}/run" || {
  [ -d "${mnt}/run" ] || sudo -E mkdir "${mnt}/run"
  sudo -E mount -t tmpfs  -o nodev,noexec,nosuid,mode=0755 tmpfs  "${mnt}/run"
  [ -d "${mnt}/run/lock" ] || sudo -E mkdir "${mnt}/run/lock"
}

# RootFS config

chroot mnt /usr/bin/env ARCH=$ARCH OS=$OS UUID=$UUID bash -l <<EOF

export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBIAN_FRONTEND=noninteractive
export LANG=C
export LANGUAGE=C
export LC_ALL=C

# Users

groups="adm,dialout,cdrom,floppy,audio,dip,video,plugdev,lxd"

groupadd --system lxd
groupadd admin

useradd -m -s /usr/sbin/nologin -G "${groups}" "${OS}"
passwd -l "${OS}"
grep -qa "DenyUsers ${OS}" /etc/ssh/sshd_config || echo "DenyUsers ${OS}" >>/etc/ssh/sshd_config
cp -a /etc/skel/. /home/"${OS}"/
chown "${OS}:" /home/"${OS}"/.* /home/"${OS}"/.ssh/*
sed -i "s/User admin/User ${OS}/g" /home/${OS}/.ssh/config

useradd -m -s /bin/bash -g admin -G "${groups}" admin
echo "admin:changeme" | chpasswd
usermod -aG sudo admin
cp -a /etc/skel/. /home/admin/
chown admin: /home/admin/.* /home/admin/.ssh/*

cp -a /etc/skel/. /root/
sed -i 's/User admin/User root/g' /root/.ssh/config

apt-get update -y
apt-get upgrade -y

# Default packages

apt-get install -y \
  apparmor \
  ca-certificates \
  cloud-init \
  cloud-utils \
  conntrack \
  cron \
  curl \
  dosfstools \
  e2fsprogs \
  gdisk \
  git \
  gnupg \
  hdparm \
  iproute2 \
  iputils-ping \
  libcap2-bin \
  libseccomp2 \
  locales \
  lvm2 \
  mdadm \
  mdadm \
  mokutil \
  mtd-utils \
  mtools \
  netplan.io \
  nvme-cli \
  openssl \
  parted \
  pv \
  smartmontools \
  software-properties-common \
  ssh \
  sudo \
  u-boot-tools \
  ufw \
  unzip \
  usbutils \
  util-linux \
  vim \
  zsh

# systemd packages (recommended)

apt-get install -y \
  dbus \
  systemd \
  systemd-sysv

# Grub packages (optional)

# apt-get install -y \
#   grub-efi \
#   initramfs-tools

# Service

systemctl enable \
  cloud-init \
  journal-to-tty

# Zsh config (optional)

# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# mv ~/.oh-my-zsh /opt/oh-my-zsh

# for usr in admin ubuntu root; do
#   chsh -s $(command -v zsh) $usr
# done

# Grub config (optional)

# sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
# sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
# if ! grep -q 'init_on_alloc=0' /etc/default/grub; then
#   sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 init_on_alloc=0"/' /etc/default/grub
# fi

# update-grub
# grub-install \
#   --target=${ARCH}-efi \
#   --efi-directory=/boot/efi \
#   --bootloader-id=${OS} \
#   --recheck

# cd /etc/grub.d
# patch 10_linux < ~/grub-10_linux-socfpga.patch

# Cleanup

apt autoremove -y --purge
apt clean -y
rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* ~/.bash_history
echo -n >/etc/machine-id
history -c; exit
EOF

# Unmount

mountpoint -q "${mnt}/run" && {
  echo "Unmounting ${mnt}/run"
  sudo -E umount -l "${mnt}/run" || echo "Warning: Failed to unmount ${mnt}/run"
}

mountpoint -q "${mnt}/dev/pts" && {
  echo "Unmounting ${mnt}/dev/pts"
  sudo -E umount -l "${mnt}/dev/pts" || echo "Warning: Failed to unmount ${mnt}/dev/pts"
}

mountpoint -q "${mnt}/dev" && {
  echo "Unmounting ${mnt}/dev"
  sudo -E umount -l "${mnt}/dev" || echo "Warning: Failed to unmount ${mnt}/dev"
}

mountpoint -q "${mnt}/proc" && {
  echo "Unmounting ${mnt}/proc"
  sudo -E umount -l "${mnt}/proc" || echo "Warning: Failed to unmount ${mnt}/proc"
}

mountpoint -q "${mnt}/sys" && {
  echo "Unmounting ${mnt}/sys"
  sudo -E umount -l "${mnt}/sys" || echo "Warning: Failed to unmount ${mnt}/sys"
}

[ -h "${mnt}/dev/stderr" ] && sudo -E rm -f "${mnt}/dev/stderr"
[ -h "${mnt}/dev/stdout" ] && sudo -E rm -f "${mnt}/dev/stdout"
[ -h "${mnt}/dev/stdin" ] && sudo -E rm -f "${mnt}/dev/stdin"
[ -h "${mnt}/dev/fd" ] && sudo -E rm -f "${mnt}/dev/fd"

# Boot args (optional)

quiet splash init_on_alloc=0 \
console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw \
systemd.unified_cgroup_hierarchy=1 systemd.legacy_systemd_cgroup_controller=0
```

## Image

```shell

export DEV="/dev/sdb"
export FS=$(sudo losetup -Pf --show build/agilex5/ubuntu-socfpga-aarch64.img)

# Partition

# EFI
sudo parted -s "$DEV" mklabel gpt
sudo parted -s "$DEV" mkpart EFI fat32 1024 1536
sudo parted -s "$DEV" set 1 esp on

# BOOT
sudo parted -s "$DEV" mkpart BOOT ext4 1536 3584

# ROOT
sudo parted -s "$DEV" mkpart ROOT ext4 3584 100%

# Ubuntu
sudo partx "${DEV}"

sudo dd if=${FS}p1 of=${DEV}1 bs=512 conv=fsync status=progress
sudo dd if=${FS}p2 of=${DEV}2 bs=1M conv=fsync status=progress
sudo dd if=${FS}p3 of=${DEV}3 bs=1G conv=fsync status=progress

sync
sudo losetup -d "$FS"

sudo e2fsck -f "${DEV}1"
sudo e2fsck -f "${DEV}2"
sudo e2fsck -f "${DEV}3"
```

## Boot Env

```shell
# u-boot env
if test -z ${scriptaddr}; then setenv scriptaddr 0x02100000; fi
setenv bootcmd '\
  if ext4load mmc 0:2 ${scriptaddr} boot.scr; then \
    echo "== boot.scr found, executing =="; \
    source ${scriptaddr}; \
  else \
    echo "== no boot.scr on mmc 0:2 =="; \
  fi; \
  echo "== running distro_bootcmd =="; \
  if run distro_bootcmd; then \
    echo "distro_bootcmd returned (no successful boot)"; \
  fi; \
  echo "== fallback: UEFI Boot Manager =="; \
  bootefi bootmgr;'
saveenv
```

## Cloud Init

```shell
sudo cloud-init clean --logs

sudo cloud-init init
sudo cloud-init modules --mode=config
sudo cloud-init modules --mode=final
```

## Debug

```shell
setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p3 rw rootwait init_on_alloc=0 systemd.unified_cgroup_hierarchy=1 systemd.legacy_systemd_cgroup_controller=0"
load mmc 0:2 ${kernel_addr_r} vmlinuz
load mmc 0:2 ${fdt_addr_r} socfpga.dtb
load mmc 0:2 ${ramdisk_addr_r} initrd.img
bootz ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
```
