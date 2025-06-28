#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2025 Schubert Anselme <schubert@anselm.es>

# Export environment variables
GPG_TTY="$(tty)"
export GPG_TTY

export EDITOR="vi"
export GO11MODULE="on"

# Re-export PATH
export SCRIPTS="/workspace/scripts"
export TOOLS="/workspace/tools"

export LOCAL_BIN="${HOME}/.local"

export CARGO_HOME="/usr/local/rust/cargo"
export GOPATH="/usr/local/go"
export KREW_ROOT="/usr/local/krew"
export RUSTUP_HOME="/usr/local/rust/rustup"

export PATH="${LOCAL_BIN}:${KREW_ROOT}/bin:${CARGO_HOME}/bin:${GOPATH}/bin:${TOOLS}${PATH:+:${PATH}}"

# SSH Agent
if ! ssh-add -l >>/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add -k >/dev/null 2>&1
fi
