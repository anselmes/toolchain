#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

# install rust
if [[ -z $(command -v rustup) ]]; then
  sudo apt-get update -yq
  sudo apt-get install -yq --no-install-recommends rustup
fi

# set rust toolchain
if [[ -z $(command -v rustc) ]]; then
  rustup default stable
  rustup component add rust-src
fi

# install bindgen-cli
command -v bindgen >/dev/null 2>&1 || echo cargo install bindgen-cli
cargo generate --version >/dev/null 2>&1 || echo cargo install cargo-generate
# cargo xtask >/dev/null 2>&1 || cargo install bpf-linker # fixme: bpf-linker

rustc --version
cargo --version
cargo generate --version
bindgen --version
