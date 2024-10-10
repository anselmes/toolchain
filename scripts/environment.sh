#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

# Export environment variables
GPG_TTY="$(tty)"
export GPG_TTY

export EDITOR="vi"
export GO11MODULE="on"

# Re-export PATH
export SCRIPTS="/workspace/scripts"
export TOOLS="/workspace/tools"

export CARGO_HOME="/usr/local/rust/cargo"
export GOPATH="/usr/local/go"
export KREW_ROOT="/usr/local/krew"
export RUSTUP_HOME="/usr/local/rust/rustup"

export PATH="${KREW_ROOT}/bin:${CARGO_HOME}/bin:${GOPATH}:${TOOLS}${PATH:+:${PATH}}"

# SSH Agent
eval "$(ssh-agent -s)"
ssh-add -l >>/dev/null
exit_code=$?
[[ ! ${exit_code} -eq 0 ]] && ssh-add -k
