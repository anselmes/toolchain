#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2025 Schubert Anselme <schubert@anselm.es>

# ref: https://github.com/johanbrandhorst/grpc-gateway-boilerplate/blob/main/scripts/generate-swagger-ui.sh
# source scripts/aliases.sh
# source scripts/environment.sh

cache_dir=".cache/swagger-ui"
output_dir="docs/openapi"
swagger_ui_repo="https://github.com/swagger-api/swagger-ui.git"
swagger_ui_version="${1:-v5.18.2}"

escape_str() {
  echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

if [[ -z ${swagger_ui_version} ]]; then
  echo "missing ${swagger_ui_version}"
  exit 1
fi

[[ ! -d ${output_dir} ]] && mkdir -p "${output_dir}"

# cache swagger-ui dist
if [[ ! -d ${cache_dir} ]]; then
  mkdir -p "${cache_dir}"
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "${swagger_ui_version}" "${swagger_ui_repo}" "${tmp}"
  cp -r "${tmp}/dist/"* "${cache_dir}"
  cp -r "${tmp}/LICENSE" "${cache_dir}"
  rm -rf "${tmp}"
fi

# fixme: populate swagger.json
buf generate
tmp="    urls: ["
for i in $(find "${output_dir}" -name "*.swagger.json"); do
  escaped_gen_dir="$(escape_str "${output_dir}/")"
  path="${i//${escaped_gen_dir}/}"
  tmp="${tmp}{\"url\":\"${path}\",\"name\":\"${path}\"},"
done
# delete last characters from $tmp
tmp="${tmp//.$/}"
tmp="${tmp}],"

# generate swagger-ui
#find "${output_dir}" -type f -name "*.swagger.json" -delete
mkdir -p "${output_dir}"
cp -r "${cache_dir}/"* "${output_dir}"

# fixme: replace the default URL
line="$(cat "${output_dir}/swagger-initializer.js" | grep -n "url" | cut -f1 -d:)"
escaped_tmp="$(escape_str "${tmp}")"
sed -i'' -e "${line} s/^.*$/${escaped_tmp}/" "${output_dir}/swagger-initializer.js"
rm -f "${output_dir}/swagger-initializer.js-e"

# fixme: optionally trunk.io
trunk fmt "${output_dir}"
