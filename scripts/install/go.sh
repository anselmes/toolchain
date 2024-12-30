#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

# install golang
if [[ -z $(command -v go) ]]; then
  sudo apt-get update -yq
  sudo apt-get install -yq --no-install-recommends golang
fi

# install packages
command -v sbctl || go install github.com/foxboron/sbctl/cmd/sbctl@53e074d6934f5ecfffa81a576293219c717f7d19 # 0.16 https://github.com/Foxboron/sbctl/commit/53e074d6934f5ecfffa81a576293219c717f7d19
command -v buf || go install github.com/bufbuild/buf/cmd/buf@8482b8f2dc17e93ac8a490cdfd86ff20f0bd1037       # v1.48.0 https://github.com/bufbuild/buf/commit/8482b8f2dc17e93ac8a490cdfd86ff20f0bd1037

go version
sbctl status || true
