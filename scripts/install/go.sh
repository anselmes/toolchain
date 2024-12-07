#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source ../alias.sh
source ../environment.sh

# install golang
if [[ -z $(command -v go) ]]; then
  sudo apt-get update -yq
  sudo apt-get install -yq --no-install-recommends golang
fi

# install sbctl
if [[ -z $(command -v sbctl) ]]; then
  # version: 0.16
  # https://github.com/Foxboron/sbctl/commit/53e074d6934f5ecfffa81a576293219c717f7d19
  go install github.com/foxboron/sbctl/cmd/sbctl@53e074d6934f5ecfffa81a576293219c717f7d19
fi

go version
sbctl status
