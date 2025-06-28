#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2025 Schubert Anselme <schubert@anselm.es>

# source scripts/aliases.sh
source scripts/environment.sh

generate_root_ca() {
  config="${1}"
  [[ -z ${config} ]] && echo "missing config file" && exit 1

  export name="$(yq '.metadata.name' "${config}")"
  export site_dir="$(yq '.status.site_dir' "${config}")"

  export $(getenv <(yq '.site.config' "${config}"))
  export $(yq --output-format shell '.status' "${config}" | tr -d "'")

  stat "${pki_ca_cert_file}" >/dev/null 2>&1 ||
    openssl req \
      -new \
      -x509 \
      -days "${pki_ca_days}" \
      -extensions v3_ca \
      -keyout "${pki_ca_key_file}" \
      -out "${pki_ca_cert_file}" \
      -passout pass: \
      -subj "${pki_ca_subj}"

  stat "${pki_ca_bundle}" >/dev/null 2>&1 ||
    openssl pkcs12 \
      -export \
      -in "${pki_ca_cert_file}" \
      -inkey "${pki_ca_key_file}" \
      -out "${pki_ca_bundle}" \
      -passin pass: \
      -passout pass:
}

generate_intermediate_ca() {
  config="${1}"
  intermediate_ca_subj="${2}"
  intermediate_ca_valid_for="${3}"
  intermediate_ca_key_file="${4}"
  intermediate_ca_cert_file="${5}"
  intermediate_ca_bundle="${6}"

  export $(getenv <(yq '.status' "${config}" | grep pki))

  [[ -z ${config} ]] && echo "missing config file" && exit 1
  [[ -z ${intermediate_ca_subj} ]] && echo "missing intermediate subject" && exit 1
  [[ -z ${intermediate_ca_valid_for} ]] && echo "missing intermediate valid for" && exit 1
  [[ -z ${intermediate_ca_key_file} ]] && echo "missing intermediate key file" && exit 1
  [[ -z ${intermediate_ca_cert_file} ]] && echo "missing intermediate ca file" && exit 1
  [[ -z ${intermediate_ca_bundle} ]] && echo "missing intermediate ca bundle file" && exit 1

  out_dir="$(dirname "${intermediate_ca_cert_file}")"

  stat "${intermediate_ca_cert_file}" >/dev/null 2>&1 ||
    openssl genrsa -out "${intermediate_ca_key_file}"

  if ! stat "${intermediate_ca_cert_file}" >/dev/null 2>&1; then
    openssl req \
      -new \
      -key "${intermediate_ca_key_file}" \
      -out /tmp/intermediate-ca.csr \
      -subj "${intermediate_ca_subj}"

    cd "${out_dir}" || exit
    openssl ca \
      -batch \
      -notext \
      -rand_serial \
      -cert "${pki_ca_cert_file}" \
      -days "${intermediate_ca_valid_for}" \
      -extensions v3_ca \
      -in /tmp/intermediate-ca.csr \
      -keyfile "${pki_ca_key_file}" \
      -out "${intermediate_ca_cert_file}" \
      -outdir . \
      -passin pass: \
      -policy policy_anything \
      -subj "${intermediate_ca_subj}"
    popd || exit
  fi

  stat "${intermediate_ca_bundle}" >/dev/null 2>&1 ||
    openssl pkcs12 \
      -export \
      -in "${intermediate_ca_cert_file}" \
      -inkey "${intermediate_ca_key_file}" \
      -out "${intermediate_ca_bundle}" \
      -passout pass:

  rm -f /tmp/intermediate-ca.csr
}

case "${1}" in
--root-ca)
  generate_root_ca "${2}"
  ;;
--intermediate-ca)
  generate_intermediate_ca "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}"
  ;;
*)
  echo """
Usage: ${0} [OPTIONS]

OPTIONS:
  --root-ca <config-file>
  --intermediate-ca <config-file> <subject> <days> <key-file> <ca-file> <ca-bundle-file>

EXAMPLES:
  ${0} --intermediate-ca '/C=CA/ST=Ontario/L=Toronto/O=LabOS/OU=LabOS/CN=LabOS Intermediate CA' 365 'ca.key' 'ca.crt' 'ca.pfx'
"""
  exit 1
  ;;
esac
