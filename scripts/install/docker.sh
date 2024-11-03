#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

export os="$(uname | tr '[:upper:]' '[:lower:]')"

if [[ "${os}" == "linux" ]]; then
  export os="$(. /etc/os-release && echo "${ID}")"

  export $(yq --output-format shell '
    .packages.group[] |
    select(.name == "docker") |
    (.. | select(tag == "!!str")) |= envsubst
  ' config/versions.yaml | tr -d "'")

  remove_packages=($(get_env_var "remove_" d))
  for pkg in "${remove_packages[@]}"; do
    apt-get remove -y "${pkg}"
  done

  keyring_url="$(get_env_var "keyring")"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL ${keyring_url} | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # add docker repository
  repo_url="$(get_env_var "repo")"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    ${repo_url} \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

  # install packages
  add_packages="$(get_env_var "add_")"
  apt-get update -yq
  apt-get install -y "${add_packages[*]}"
# note: macOS via Brewfile
else
  echo "unsupported operating system"
fi
