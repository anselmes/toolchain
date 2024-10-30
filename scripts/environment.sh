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

export LOCAL_BIN="${HOME}/.local"

export CARGO_HOME="/usr/local/rust/cargo"
export GOPATH="/usr/local/go"
export KREW_ROOT="/usr/local/krew"
export RUSTUP_HOME="/usr/local/rust/rustup"

export PATH="${LOCAL_BIN}:${KREW_ROOT}/bin:${CARGO_HOME}/bin:${GOPATH}:${TOOLS}${PATH:+:${PATH}}"

# SSH Agent
if ! ssh-add -l >>/dev/null; then
  eval "$(ssh-agent -s)"
  ssh-add -k
fi

# Functions
cache() {
  CACHE_DIR=".cache"

  REPO="${1}"
  ITEMS="${2}"
  VERSION="${3:-main}"

  [[ -z "${REPO}" ]] && echo "ERROR: repository is required" && return 1
  [[ -z "${ITEMS}" ]] && echo "ERROR: item list is required" && return 1

  if [[ ! -d "${CACHE_DIR}" ]]; then
    mkdir -p "${CACHE_DIR}"
    tmp="$(mktemp -d)"
    gh repo clone "${REPO}" "${tmp}" -- --depth 1 --branch "${VERSION}"

    for ITEM in ${ITEMS[@]}; do
      cp -r "${tmp}/${ITEM}" "${CACHE_DIR}/"
    done

    rm -rf "${tmp}"
  fi
}
