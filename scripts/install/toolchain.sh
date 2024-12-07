#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
# source scripts/environment.sh

apt-get update -yq
apt-get install -yq --no-install-recommends \
  binutils \
  bison \
  build-essential \
  ccache \
  clang \
  cmake \
  dfu-util \
  flex \
  gcc \
  git \
  gnupg2 \
  gperf \
  libc6-dev \
  libcurl4 \
  libedit2 \
  libelf-dev \
  libffi-dev \
  libgcc-9-dev \
  libncurses6 \
  libsqlite3-0 \
  libssl-dev \
  libstdc++-9-dev \
  libusb-1.0-0 \
  libxml2 \
  libz3-dev \
  lld \
  llvm \
  ninja-build \
  pkg-config \
  python3 \
  python3-pip \
  python3-venv \
  tzdata \
  uuid-dev \
  wget \
  zlib1g-dev
