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
