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

# fixme: verify yq version 4
if [[ -z $(command -v "yq") ]]; then
  echo "yq is not installed"
  exit 1
fi

check_installed() {
  name="${1}"
  if [[ -n $(command -v "${name}") ]]; then
    echo "${name} is already installed"
    continue
  fi
}

# todo: add packages
# todo: remove packages

# note: package groups
package_groups="$(yq '.package.group[] | .name' "${VERSION_CONFIG}")"
for name in ${package_groups[@]}; do
  export name="${name}"
  export $(getenv <(yq '.package.group[] | select(.name == env(name))' "${VERSION_CONFIG}"))

  # check already installed
  if [[ -n $(command -v "${name}") ]]; then
    echo "${name} is already installed"
    continue
  fi

  # check enabled
  if [[ "${enabled}" == "false" ]]; then
    echo "${name} is not enabled"
    continue
  fi

  # install package group
  if [[ -n $(command -v "${type}") ]]; then
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
  export $(getenv <(yq '.binary[] | select(.name == env(name))' "${VERSION_CONFIG}"))

  # check already installed
  if [[ -n $(command -v "${name}") ]]; then
    echo "${name} is already installed"
    continue
  fi

  # check enabled
  if [[ "${enabled}" == "false" ]]; then
    echo "${name} is not enabled"
    continue
  fi

  if [[ "${archs[@]}" =~ "${arch}" ]]; then
    echo "================== installing ${name} ${version} on ${os} for ${arch}" ==================
    export url="$(printf "${url}" | envsubst)"
    export path="$(printf "${path}" | envsubst)"
    case "${type}" in
    archive)
      # set extracted path to /tmp/<name> if not provided
      [[ "${path}" == "" ]] && path="${name}"

      if [[ "${workspace}" == "" ]]; then
        sudo mkdir -p "${workspace}"
        sudo chmod -R 777 "${workspace}"
      fi

      curl -fsSLo "/tmp/${name}.tgz" "${url}"
      tar -xzf "/tmp/${name}.tgz" -C /tmp/
      sudo install "/tmp/${path}" "/usr/local/bin/${name}"
      ${name} version
      ;;
    executable)
      curl -fsSLo "/tmp/${name}" "${url}"
      sudo install "/tmp/${name}" "/usr/local/bin/${name}"
      ${name} version
      ;;
    *)
      echo "unsupported binary package"
      ;;
    esac
  else
    echo "unsupported architecture"
  fi

  post_install_cmd=$(yq '.binary[] | select(.name == env(name)) | .post' "${VERSION_CONFIG}")
  /usr/local/bin/${name} ${post_install_cmd}
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
