#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source ../alias.sh
source ../environment.sh

# install rust
if [[ -z $(command -v rustup) ]]; then
  sudo apt-get update -yq
  sudo apt-get install -yq --no-install-recommends rustup
fi

# set rust toolchain
if [[ -n $(command -v rustc) ]]; then
  rustup default stable
  rustup component add rust-src
fi

# install bindgen-cli
[[ -n $(command -v bindgen-cli) ]] || cargo install bindgen-cli

rustc --version
cargo --version
bindgen --version
