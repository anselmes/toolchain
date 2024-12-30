#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/alias.sh
source scripts/environment.sh

VERSION_CONFIG="config/versions.yaml"

export arch="$(uname -m)"
export os="$(uname | tr '[:upper:]' '[:lower:]')"

if [[ "${arch}" == "aarch64" ]]; then
  export arch="arm64"
fi

# todo: packages
# note: package groups
package_groups="$(yq '.package.group[] | .name' "${VERSION_CONFIG}")"
for name in ${package_groups[@]}; do
  export name="${name}"
  export $(getenv <(yq '.package.group[] | select(.name == env(name))' "${VERSION_CONFIG}"))

  if [[ -n $(command -v "${name}") ]]; then
    echo "${name} is already installed"
    continue
  elif [[ -n $(command -v "${type}") ]]; then
    echo "================== installing ${name} ${version} on ${os} for ${arch}" ==================
    sudo apt-get update -yq
    sudo apt-get remove -y "$(printf "${remove}" | sed 's/,/ /g' | tr -d '()')"
    sudo apt-get install -y "$(printf "${add}" | sed 's/,/ /g' | tr -d '()')"
  else
    echo "unsupported package manager"
  fi
done

# note: binaries
binaries="$(yq '.binary[] | .name' "${VERSION_CONFIG}")"

for name in ${binaries[@]}; do
  export name="${name}"
  yq '.binary[] | select(.name == env(name))' "${VERSION_CONFIG}"
  export $(getenv <(yq '.binary[] | select(.name == env(name))' "${VERSION_CONFIG}"))

  if [[ -n $(command -v "${name}") ]]; then
    echo "${name} is already installed"
    continue
  elif [[ "${archs[@]}" =~ "${arch}" ]]; then
    echo "================== installing ${name} ${version} on ${os} for ${arch}" ==================
    export url="$(printf "${url}" | envsubst)"
    case "${type}" in
    archive)
      curl -fsSLo "/tmp/${name}.tgz" "${url}"
      tar -xzf "/tmp/${name}.tgz" -C /tmp/
      install "/tmp/${os}-${arch}/${name}" "/usr/local/bin/${name}"
      "${name}" version
      ;;
    executable)
      curl -fsSLo "/tmp/${name}" "${url}"
      install "/tmp/${name}" "/usr/local/bin/${name}"
      "${name}" version
      ;;
    *)
      echo "unsupported binary package"
      ;;
    esac
  else
    echo "unsupported architecture"
  fi
done

# note: plugins
plugins="$(yq '.plugin[] | .name' "${VERSION_CONFIG}")"
for name in ${plugins[@]}; do
  export name="${name}"
  installer="$(yq '.plugin[] | select(.name == env(name)) | .installer' "${VERSION_CONFIG}")"

  if [[ -z $(command -v "${name}") ]]; then
    echo "{name} is not installed"
  elif "${name}" "${installer}" >/dev/null 2>&1; then
    echo "================== installing ${name} plugins ================="
    list=$(yq '.plugin[] | select(.name == env(name)) | .list[]' "${VERSION_CONFIG}")
    "${name}" "${installer}" install ${list[*]} || true
  else
    echo "unsupported plugin installer"
  fi
done
