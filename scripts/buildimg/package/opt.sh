#!/bin/bash

apt-get update -yq
apt-get upgrade -y
apt-get install -y \
  bcwl-kernel-source \
  build-essential \
  dkms \
  htop \
  hyfetch \
  ipheth-utils \
  tree \
  usbmuxd
