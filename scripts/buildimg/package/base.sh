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
  gnupg \
  grub-efi \
  initramfs-tools \
  iproute2 \
  iputils-ping \
  libseccomp2 \
  locales \
  mdadm \
  mtools \
  openssl \
  parted \
  software-properties-common \
  ssh \
  sudo \
  systemd \
  systemd-sysv \
  unzip \
  util-linux \
  vim
