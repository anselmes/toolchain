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

export PATH="${LOCAL_BIN}:${KREW_ROOT}/bin:${CARGO_HOME}/bin:${GOPATH}/bin:${TOOLS}${PATH:+:${PATH}}"

# SSH Agent
if ! ssh-add -l >>/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add -k >/dev/null 2>&1
fi

# Functions
getenv() {
  local source="${1}"
  yq '.. |(
    ( select(kind == "scalar" and parent | kind != "seq") | (path | join("_")) + "=''" + . + "''"),
    ( select(kind == "seq") | (path | join("_")) + "=(" + (map("''" + . + "''") | join(",")) + ")")
  )' "${source}"
}

getenval() {
  local source="${1}"
  local key="${2}"
  local delimiter="${3:-=}"
  printf "${source}" | grep "${key}" | awk -F "${delimiter}" '{ print $2 }'
}

getenvarval() {
  local key="${1}"
  getenval $(env) "${key}" "="
  # env | awk -F "=" "/${key}/ { print \$2 }"
}

createiso() {
  isocmd="genisoimage"
  if [[ -z $(command -v "${isocmd}") ]]; then
    isocmd="mkisofs"
    if [[ -z $(command -v "${isocmd}") ]]; then
      echo "genisoimage nor mkisofs found"
      exit 1
    fi
  fi

  "${isocmd}" -joliet -rock -output "${1}" -volid cidata "${@:2}"
}

createvol() {
  local vol_file="${1}"
  local img_file="${2}"

  [[ -z ${vol_file} ]] && echo "name is required" && exit 1
  [[ -z ${img_file} ]] && echo "image file not provided"

  if [[ -n ${img_file} ]]; then
    img_dir="$(dirname "${img_file}")"
    stat -d "${img_dir}" >/dev/null 2>&1 ||
      mkdir -p "${img_dir}"

    grep -qa "${vol_file}" <(sudo ls "${vol_file}") ||
      qemu-img create -b "${img_file}" -f qcow2 -F qcow2 "${vol_file}" "${3:-16G}"
  else
    grep -qa "${vol_file}" <(sudo ls "${vol_file}") ||
      qemu-img create -f qcow2 "${vol_file}" "${3:-16G}"
  fi
}

cache() {
  local cache_dir=".cache"

  local repo="${1}"
  local items="${2}"
  local version="${3:-main}"

  [[ -z ${repo} ]] && echo "ERROR: repository is required" && return 1
  [[ -z ${items} ]] && echo "ERROR: item list is required" && return 1

  if [[ ! -d ${cache_dir} ]]; then
    mkdir -p "${cache_dir}"
    tmp="$(mktemp -d)"
    gh repo clone "${repo}" "${tmp}" -- --depth 1 --branch "${version}"

    for item in ${items[@]}; do
      cp -r "${tmp}/${item}" "${cache_dir}/"
    done

    rm -rf "${tmp}"
  fi
}
