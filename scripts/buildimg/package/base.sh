#!/bin/bash

apt-get update -yq
apt-get upgrade -y
apt-get install -y \
  apparmor \
  ca-certificates \
  cloud-init \
  conntrack \
  cron \
  curl \
  dbus \
  dosfstools \
  gdisk \
  git \
  gnupg \
  grub-efi \
  initramfs-tools \
  iproute2 \
  iputils-ping \
  libcap2-bin \
  libseccomp2 \
  locales \
  mdadm \
  mokutil \
  mtools \
  openssl \
  parted \
  software-properties-common \
  ssh \
  sudo \
  systemd \
  systemd-sysv \
  unzip \
  usbutils \
  util-linux \
  vim
