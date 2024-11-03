#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
source scripts/aliases.sh
source scripts/environment.sh

generate_root_ca() {
  stat "${spec_config_pki_ca_cert_file}" >/dev/null 2>&1 ||
    openssl req \
      -new \
      -x509 \
      -days ${spec_config_pki_ca_days} \
      -extensions v3_ca \
      -keyout "${spec_config_pki_ca_key_file}" \
      -out "${spec_config_pki_ca_cert_file}" \
      -passout pass: \
      -subj "${spec_config_pki_ca_subj}"

  stat "${config_pki_ca_bundle}" >/dev/null 2>&1 ||
    openssl pkcs12 \
      -export \
      -in "${spec_config_pki_ca_cert_file}" \
      -inkey "${spec_config_pki_ca_key_file}" \
      -out "${spec_config_pki_ca_bundle}" \
      -passin pass: \
      -passout pass:
}

generate_intermediate_ca() {
  INTERMEDIATE_CERT_SUBJ="${2}"
  INTERMEDIATE_CA_VALID_FOR="${3}"
  INTERMEDIATE_KEY_FILE="${4}"
  INTERMEDIATE_CA_FILE="${5}"
  INTERMEDIATE_CA_BUNDLE_FILE="${6}"

  [[ -z "${INTERMEDIATE_CERT_SUBJ}" ]] && echo "missing intermediate subject" && exit 1
  [[ -z "${INTERMEDIATE_CA_VALID_FOR}" ]] && echo "missing intermediate valid for" && exit 1
  [[ -z "${INTERMEDIATE_KEY_FILE}" ]] && echo "missing intermediate key file" && exit 1
  [[ -z "${INTERMEDIATE_CA_FILE}" ]] && echo "missing intermediate ca file" && exit 1
  [[ -z "${INTERMEDIATE_CA_BUNDLE_FILE}" ]] && echo "missing intermediate ca bundle file" && exit 1

  OUT_DIR="$(dirname ${INTERMEDIATE_CA_FILE})"

  stat "${INTERMEDIATE_CA_FILE}" >/dev/null 2>&1 ||
    openssl genrsa -out "${INTERMEDIATE_KEY_FILE}"

  if ! stat "${INTERMEDIATE_CA_FILE}" >/dev/null 2>&1; then
    openssl req \
      -new \
      -key "${INTERMEDIATE_KEY_FILE}" \
      -out /tmp/intermediate-ca.csr \
      -subj "${INTERMEDIATE_CERT_SUBJ}"

    cd "${OUT_DIR}"
    openssl ca \
      -batch \
      -notext \
      -rand_serial \
      -cert "${spec_config_pki_ca_cert_file}" \
      -days ${INTERMEDIATE_CA_VALID_FOR} \
      -extensions v3_ca \
      -in /tmp/intermediate-ca.csr \
      -keyfile "${spec_config_pki_ca_key_file}" \
      -out "${INTERMEDIATE_CA_FILE}" \
      -outdir . \
      -passin pass: \
      -policy policy_anything \
      -subj "${INTERMEDIATE_CERT_SUBJ}"
    popd
  fi

  stat "${INTERMEDIATE_CA_BUNDLE_FILE}" >/dev/null 2>&1 ||
    openssl pkcs12 \
      -export \
      -in "${INTERMEDIATE_CA_FILE}" \
      -inkey "${INTERMEDIATE_KEY_FILE}" \
      -out "${INTERMEDIATE_CA_BUNDLE_FILE}" \
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
  --intermediate-ca <config-file> <subject> <days> <key-file> <ca-file> <ca-bundle-file>

EXAMPLES:
  ${0} --intermediate-ca '/C=CA/ST=Ontario/L=Toronto/O=LabOS/OU=LabOS/CN=LabOS Intermediate CA' 365 'ca.key' 'ca.crt' 'ca.pfx'
"""
  exit 1
  ;;
esac
