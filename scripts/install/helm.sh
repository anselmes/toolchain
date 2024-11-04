#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

export $(yq --output-format shell '
  .binaries[] |
  select(.name == "helm")
' config/versions.yaml | tr -d "'")

export os="$(uname | tr '[:upper:]' '[:lower:]')"
export arch="$(uname -m)"

archs=($(get_env_var "arch_"))
url="$(printf ${url} | envsubst)"

[[ DEBUG -eq 1 ]] && echo """
os: ${os}
arch: ${arch}

url: ${url}
version: ${version}
support: ${archs[*]}
"""

# install helm
if [[ "${archs[@]}" =~ "${arch}" ]]; then
  echo curl -fsSLo /tmp/helm.tgz "${url}"
  echo tar -xzf /tmp/helm.tgz
  echo install "/tmp/${os}-${arch}/helm /usr/local/bin/helm"
  echo helm version
else
  echo "unsupported architecture"
fi
