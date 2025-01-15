#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

ARCH="$(uname -m)"
SWIFT_DEV_BUILD="DEVELOPMENT-SNAPSHOT-2025-01-13-a"
SWIFT_DEV_STATIC_SDK_BUILD="DEVELOPMENT-SNAPSHOT-2025-01-09-a"
SWIFT_DEV_STATIC_SDK_CHECKSUM="67f765e0030e661a7450f7e4877cfe008db4f57f177d5a08a6e26fd661cdd0bd"
SWIFT_DEV_VERSION="6.1"
SWIFT_STATIC_SDK_CHECKSUM="2af563449e7994c070b6a3a477d3978df9ede084436c8bb7b3d57ee2ae8fabd2"
SWIFT_VERSION="6.0.3"

# install swift
if [[ -z $(command -v swift) ]]; then
  if [[ ${ARCH} == "aarch64" ]];then
    URL="https://download.swift.org/swift-${SWIFT_DEV_VERSION}-branch/ubuntu2404-${ARCH}/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_BUILD}/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_BUILD}-ubuntu24.04-${ARCH}.tar.gz"
  else
    URL="https://download.swift.org/swift-${SWIFT_DEV_VERSION}-branch/ubuntu2404/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_BUILD}/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_BUILD}-ubuntu24.04.tar.gz"
  fi
  curl -fsSLo /tmp/swift.tgz "${URL}"
  # fixme: verify download
  # curl -fsSLo /tmp/swift.tgz.sig "https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-${ARCH}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04-${ARCH}.tar.gz.sig"
  # curl https://swift.org/keys/all-keys.asc | gpg --import -
  # gpg --keyserver hkp://keyserver.ubuntu.com --refresh-keys Swift
  # gpg --verify /tmp/swift.tgz.sig /tmp/swift.tgz
  tar -xzf /tmp/swift.tgz -C / --strip-components=1
  rm -f /tmp/swift.tgz*
fi

# static sdk
# todo: choose between release and dev
# grep -q "swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1" <(swift sdk list) || swift sdk install \
#   --checksum "${SWIFT_STATIC_SDK_CHECKSUM}" \
#   "https://download.swift.org/swift-${SWIFT_VERSION}-release/static-sdk/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"
# swift --version
# swift sdk list
grep -q "swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_STATIC_SDK_BUILD}_static-linux-0.0.1" <(swift sdk list) || swift sdk install \
  --checksum "${SWIFT_STATIC_SDK_CHECKSUM}" \
  "https://download.swift.org/swift-${SWIFT_DEV_VERSION}-branch/static-sdk/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_STATIC_SDK_BUILD}/swift-${SWIFT_DEV_VERSION}-${SWIFT_DEV_STATIC_SDK_BUILD}_static-linux-0.0.1.artifactbundle.tar.gz"
swift --version
swift sdk list
