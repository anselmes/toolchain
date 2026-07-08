#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2025 Schubert Anselme <schubert@anselm.es>

# Parses environment variables from a YAML file and outputs them in a shell-compatible format.
#
# Usage: getenv <source>
#
# Arguments:
#   source: The path to the YAML file to parse.
#
# Example:
#   config.yaml
#   ```yaml
#   host:
#     name: localhost
#     port: 8080
#   ```
#   getenv "config.yaml"
#   # Output
#   # host_name=localhost
#   # host_port=8080
getenv() {
  local source="${1}"
  yq '.. |(
    ( select(kind == "scalar" and parent | kind != "seq") | (path | join("_")) + "=''" + . + "''"),
    ( select(kind == "seq") | (path | join("_")) + "=(" + (map("''" + . + "''") | join(",")) + ")")
  )' "${source}"
}

# Retrieves the value of a specific key from a source string.
#
# Usage: getenval <source> <key> [delimiter]
#
# Arguments:
#   source: The source string to search.
#   key: The key to search for.
#   delimiter: The delimiter to use for splitting the key-value pair. Default is "=".
#
# Example:
#   getenval "host_name=localhost" "host_name"
#   # Output
#   # localhost
getenval() {
  local source="${1}"
  local key="${2}"
  local delimiter="${3:-=}"
  printf "${source}" | grep "${key}" | awk -F "${delimiter}" '{ print $2 }'
}

# Retrieves the value of a specific environment variable from the current environment.
#
# Usage: getenvar <key>
#
# Arguments:
#   key: The key to search for.
#
# Example:
#   export host_name=localhost
#   getenvar "host_name"
#   # Output
#   # localhost
getenvarval() {
  local key="${1}"
  env | awk -F "=" "/${key}/ { print \$2 }"
}

# Creates an ISO image using `genisoimage` or `mkisofs`.
#
# Usage: createiso <output> <files...>
#
# Arguments:
#   output: The path to the ISO image to create.
#   files: The list of files to include in the ISO image.
#
# Example:
#   createiso "cidata.iso" "user-data" "meta-data"
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

# Creates a QCOW2 volume, optionally based on an existing image.
#
# Usage: createvol <name> [image] [size]
#
# Arguments:
#   name: The name of the volume to create.
#   image: The path to the image file to use as a base.
#   size: The size of the volume to create. Default is 16G.
#
# Example:
#   createvol "disk.qcow2"
#   createvol "disk.qcow2" "base.qcow2"
#   createvol "disk.qcow2" "base.qcow2" "32G"
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

# Opens a backgrounded, persistent SSH local port-forward, optionally through
# one or more bastion hosts. Refuses to start if the local port is already
# listening, so re-running this is safe.
#
# Usage: porttunnel -l <local_port> -h <remote_host> -p <remote_port> -u <user> [-b <ssh_dest>] [-j <jump_hosts>] [-i <ssh_key>]
#
# Arguments:
#   -l local_port: The local port to bind.
#   -h remote_host: The host to forward traffic to, as seen from the ssh destination.
#   -p remote_port: The port on remote_host to forward traffic to.
#   -u user: The username to authenticate as.
#   -b ssh_dest: The host ssh actually connects to. Defaults to remote_host,
#                for the case where the tunnel target is also the ssh target.
#   -j jump_hosts: Comma-separated bastion chain to traverse before reaching
#                  ssh_dest (passed to ssh -J). Optional.
#   -i ssh_key: Path to the private key to authenticate with. Optional.
#
# Example:
#   # ssh -f -J outer,inner -L 8443:target:443 -N alice@target -i ~/.ssh/id_rsa
#   porttunnel -l 8443 -h target -p 443 -u alice -j outer,inner -i ~/.ssh/id_rsa
#
#   # ssh -i ~/.ssh/id_rsa -fN -L 6443:target:6443 alice@bastion
#   porttunnel -l 6443 -h target -p 6443 -u alice -b bastion -i ~/.ssh/id_rsa
porttunnel() {
  local OPTIND opt
  local local_port="" remote_host="" remote_port="" user="" dest="" jump="" key=""

  while getopts "l:h:p:u:b:j:i:" opt; do
    case "${opt}" in
      l) local_port="${OPTARG}" ;;
      h) remote_host="${OPTARG}" ;;
      p) remote_port="${OPTARG}" ;;
      u) user="${OPTARG}" ;;
      b) dest="${OPTARG}" ;;
      j) jump="${OPTARG}" ;;
      i) key="${OPTARG}" ;;
      *)
        echo "usage: porttunnel -l <local_port> -h <remote_host> -p <remote_port> -u <user> [-b <ssh_dest>] [-j <jump_hosts>] [-i <ssh_key>]"
        return 1
        ;;
    esac
  done

  [[ -z ${local_port} ]] && echo "ERROR: -l local_port is required" && return 1
  [[ -z ${remote_host} ]] && echo "ERROR: -h remote_host is required" && return 1
  [[ -z ${remote_port} ]] && echo "ERROR: -p remote_port is required" && return 1
  [[ -z ${user} ]] && echo "ERROR: -u user is required" && return 1
  dest="${dest:-${remote_host}}"

  if lsof -nP -iTCP:"${local_port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ERROR: local port ${local_port} is already in use, skipping"
    return 1
  fi

  local cmd=(ssh -f -N -L "${local_port}:${remote_host}:${remote_port}")
  [[ -n ${key} ]] && cmd+=(-i "${key}")
  [[ -n ${jump} ]] && cmd+=(-J "${jump}")
  cmd+=("${user}@${dest}")

  "${cmd[@]}"
}

# Stops a backgrounded SSH tunnel previously started with porttunnel, by
# matching the local port in the process command line.
#
# Usage: porttunnelstop <local_port>
#
# Arguments:
#   local_port: The local port of the tunnel to stop.
#
# Example:
#   porttunnelstop 8443
porttunnelstop() {
  local local_port="${1}"
  [[ -z ${local_port} ]] && echo "ERROR: local_port is required" && return 1

  pkill -f "ssh -f -N -L ${local_port}:" &&
    echo "tunnel on port ${local_port} stopped" ||
    echo "no tunnel found on port ${local_port}"
}

# Caches files from a GitHub repository.
#
# Usage: cache <repository> <items> [version]
#
# Arguments:
#   repository: The GitHub repository to clone.
#   items: The list of items to cache.
#   version: The version of the repository to clone. Default is main.
#
# Example:
#   cache "user/repo" "item1 item2"
#   cache "user/repo" "item1 item2" "v1.0.0"
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
