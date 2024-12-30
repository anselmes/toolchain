#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

ARCH="$(uname -m)"
SWIFT_VERSION="6.0.2"
SWIFT_STATIC_SDK_CHECKSUM="aa5515476a403797223fc2aad4ca0c3bf83995d5427fb297cab1d93c68cee075"

# install swift
if [[ -z $(command -v swift) ]]; then
  curl -fsSLo /tmp/swift.tgz "https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-${ARCH}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04-${ARCH}.tar.gz"
  # fixme: verify download
  # curl -fsSLo /tmp/swift.tgz.sig "https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-${ARCH}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04-${ARCH}.tar.gz.sig"
  # curl https://swift.org/keys/all-keys.asc | gpg --import -
  # gpg --keyserver hkp://keyserver.ubuntu.com --refresh-keys Swift
  # gpg --verify /tmp/swift.tgz.sig /tmp/swift.tgz
  tar -xzf /tmp/swift.tgz -C / --strip-components=1
  rm -f /tmp/swift.tgz*
fi

# static sdk
grep -q "swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1" <(swift sdk list) || swift sdk install \
  --checksum "${SWIFT_STATIC_SDK_CHECKSUM}" \
  "https://download.swift.org/swift-${SWIFT_VERSION}-release/static-sdk/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"

swift --version
swift sdk list
