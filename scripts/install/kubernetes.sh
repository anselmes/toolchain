#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
# source scripts/environment.sh

export os="$(uname | tr '[:upper:]' '[:lower:]')"
export arch="$(uname -m)"

plugins=($(yq '.plugins.kubernetes.krew[]' config/versions.yaml))

[[ DEBUG -eq 1 ]] && echo """
os: ${os}
arch: ${arch}

plugins: ${plugins[*]}
"""

for plugin in "${plugins[@]}"; do
  kubectl krew install "${plugin}"
done
