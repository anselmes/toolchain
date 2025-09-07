#!/bin/sh

mount_chroot() {
  local mnt="${1}"

  [ -z "${mnt}" ] && mnt="/mnt"

  [ -d "${mnt}/dev" ]   || sudo -E mkdir -m 0755 "${mnt}/dev"
  [ -d "${mnt}/root" ]  || sudo -E mkdir -m 0700 "${mnt}/root"

  [ -d "${mnt}/sys" ]   || sudo -E mkdir "${mnt}/sys"
  [ -d "${mnt}/proc" ]  || sudo -E mkdir "${mnt}/proc"
  [ -d "${mnt}/tmp" ]   || sudo -E mkdir "${mnt}/tmp"

  sudo -E mkdir -p "${mnt}/var/lock"

  # Mount the core pseudo-filesystems.
  mountpoint -q "${mnt}/sys"  || sudo -E mount -t sysfs   -o nodev,noexec,nosuid  sysfs  "${mnt}/sys"
  mountpoint -q "${mnt}/proc" || sudo -E mount -t proc    -o nodev,noexec,nosuid  proc   "${mnt}/proc"

  # Prepare the /dev directory
  mountpoint -q "${mnt}/dev"  || sudo -E mount -t devtmpfs -o nosuid,mode=0755    udev  "${mnt}/dev"

  [ ! -h "${mnt}/dev/fd" ]      && sudo -E ln -s "/proc/self/fd"    "${mnt}/dev/fd"
  [ ! -h "${mnt}/dev/stdin" ]   && sudo -E ln -s "/proc/self/fd/0"  "${mnt}/dev/stdin"
  [ ! -h "${mnt}/dev/stdout" ]  && sudo -E ln -s "/proc/self/fd/1"  "${mnt}/dev/stdout"
  [ ! -h "${mnt}/dev/stderr" ]  && sudo -E ln -s "/proc/self/fd/2"  "${mnt}/dev/stderr"

  # Proper PTY setup
  mountpoint -q "${mnt}/dev/pts" || {
    [ -d "${mnt}/dev/pts" ] || sudo -E mkdir "${mnt}/dev/pts"
    sudo -E mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts "${mnt}/dev/pts"
  }

  # Mount /run as tmpfs
  mountpoint -q "${mnt}/run" || {
    [ -d "${mnt}/run" ] || sudo -E mkdir "${mnt}/run"
    sudo -E mount -t tmpfs  -o nodev,noexec,nosuid,mode=0755 tmpfs  "${mnt}/run"
    [ -d "${mnt}/run/lock" ] || sudo -E mkdir "${mnt}/run/lock"
  }
}

umount_chroot() {
  local mnt="${1}"

  [ -z "${mnt}" ] && mnt="/mnt"

  echo "Unmounting chroot environment at ${mnt}..."

  # Unmount in reverse order
  mountpoint -q "${mnt}/run" && {
    echo "Unmounting ${mnt}/run"
    sudo -E umount "${mnt}/run" || echo "Warning: Failed to unmount ${mnt}/run"
  }

  mountpoint -q "${mnt}/dev/pts" && {
    echo "Unmounting ${mnt}/dev/pts"
    sudo -E umount "${mnt}/dev/pts" || echo "Warning: Failed to unmount ${mnt}/dev/pts"
  }

  mountpoint -q "${mnt}/dev" && {
    echo "Unmounting ${mnt}/dev"
    sudo -E umount "${mnt}/dev" || echo "Warning: Failed to unmount ${mnt}/dev"
  }

  mountpoint -q "${mnt}/proc" && {
    echo "Unmounting ${mnt}/proc"
    sudo -E umount "${mnt}/proc" || echo "Warning: Failed to unmount ${mnt}/proc"
  }

  mountpoint -q "${mnt}/sys" && {
    echo "Unmounting ${mnt}/sys"
    sudo -E umount "${mnt}/sys" || echo "Warning: Failed to unmount ${mnt}/sys"
  }

  # Remove symbolic links
  [ -h "${mnt}/dev/stderr" ] && sudo -E rm -f "${mnt}/dev/stderr"
  [ -h "${mnt}/dev/stdout" ] && sudo -E rm -f "${mnt}/dev/stdout"
  [ -h "${mnt}/dev/stdin" ] && sudo -E rm -f "${mnt}/dev/stdin"
  [ -h "${mnt}/dev/fd" ] && sudo -E rm -f "${mnt}/dev/fd"

  echo "Chroot environment unmounted"
}

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS] [MOUNT_POINT]"
  echo ""
  echo "Options:"
  echo "  --cleanup    Unmount all chroot filesystems"
  echo "  --help       Show this help message"
  echo ""
  echo "Arguments:"
  echo "  MOUNT_POINT  Target mount point (default: /mnt)"
  echo ""
  echo "Examples:"
  echo "  $0                    # Mount chroot at /mnt"
  echo "  $0 /target           # Mount chroot at /target"
  echo "  $0 --cleanup         # Unmount chroot at /mnt"
  echo "  $0 --cleanup /target # Unmount chroot at /target"
}

# If script is run directly (not sourced), parse arguments and call appropriate function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "$1" in
    --cleanup)
      umount_chroot "$2"
      ;;
    --help|-h)
      show_usage
      ;;
    *)
      mount_chroot "$@"
      ;;
  esac
fi
