#!/usr/bin/env bash
# Unseals a Vault server using one or more Shamir unseal keys.
# Reads keys from (first match wins):
#   1) $VAULT_UNSEAL_KEYS (comma-separated)
#   2) /etc/vault/unseal-keys (one key per line)
#   3) /etc/vault/unseal.json (HashiCorp init JSON; parses without jq)
#
# Exit codes:
#   0 success / already unsealed
#   1 configuration/keys missing
#   2 Vault API never came up
#   3 unseal attempts failed

set -euxo pipefail

VAULT_SKIP_VERIFY=${VAULT_SKIP_VERIFY:-false}
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
# Extra curl flags (e.g., "--cacert /etc/ssl/myca.pem" or "--connect-timeout 2")
CURL_EXTRA=${CURL_EXTRA:-}
# How long to wait for Vault API to come up (seconds)
API_WAIT_SECONDS=${API_WAIT_SECONDS:-300}
# Sleep between retries while waiting on API
API_WAIT_SLEEP=${API_WAIT_SLEEP:-2}

UNSEAL_KEYS_FILE="${UNSEAL_KEYS_FILE:-/opt/vault/unseal-keys}"
UNSEAL_JSON_FILE="${UNSEAL_JSON_FILE:-/opt/vault/unseal.json}"

log() { printf '%s %s\n' "$(date -Is)" "$*" >&2; }

curl_vault() {
  # shellcheck disable=SC2086
  local extra_flags="${CURL_EXTRA}"
  if [[ "${VAULT_SKIP_VERIFY}" == "true" ]]; then
    extra_flags="${extra_flags} --insecure"
  fi
  curl -sS "${extra_flags}" "$@"
}

if ! command -v yq >/dev/null 2>&1; then
  log "ERROR: yq is required to parse Vault JSON responses. Please install yq."
  exit 1
fi

api_up() {
  # Use yq to check if Vault is initialized and reachable (yq required)
  local health_json
  health_json="$(curl_vault -s "${VAULT_ADDR}/v1/sys/health" || true)"
  # If health_json is empty, Vault is not up
  if [[ -z "${health_json}" ]]; then
    return 1
  fi
  initialized=$(echo "${health_json}" | yq -r '.initialized')
  sealed=$(echo "${health_json}" | yq -r '.sealed')
  # Vault is up if initialized is true (even if sealed)
  if [[ "${initialized}" == "true" || "${sealed}" == "true" ]]; then
    return 0
  fi
  return 1
}

is_sealed() {
  # Return 0 (true) if sealed, 1 if not sealed
  local seal_json sealed_status
  seal_json="$(curl_vault -s "${VAULT_ADDR}/v1/sys/seal-status" || true)"
  # If request failed, treat as sealed to keep retry logic simple
  if [[ -z "${seal_json}" ]]; then
    return 0
  fi
  sealed_status=$(echo "${seal_json}" | yq -r '.sealed')
  if [[ "${sealed_status}" == "true" ]]; then
    return 0
  else
    return 1
  fi
}

load_keys() {
  local keys_raw=""

  if [[ -n "${VAULT_UNSEAL_KEYS:-}" ]]; then
    keys_raw="${VAULT_UNSEAL_KEYS}"
  elif [[ -f "${UNSEAL_KEYS_FILE}" ]]; then
    # One key per line, ignore blanks/comments
    keys_raw="$(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "${UNSEAL_KEYS_FILE}" | paste -sd, -)"
  elif [[ -f "${UNSEAL_JSON_FILE}" ]]; then
    # Use yq or jq to extract unseal keys from JSON (support keys, keys_base64, unseal_keys_b64, unseal_keys_hex)
    keys_raw="$(yq -r '.unseal_keys_b64 // .unseal_keys_hex // .keys_base64 // .keys | join(",")' "${UNSEAL_JSON_FILE}" 2>/dev/null)"
  fi

  if [[ -z "${keys_raw}" ]]; then
    return 1
  fi

  IFS=',' read -r -a UNSEAL_KEYS_ARR <<<"${keys_raw}"
  # Export as global array
  export UNSEAL_KEYS_ARR
  return 0
}

unseal_with_keys() {
  local key
  for key in "${UNSEAL_KEYS_ARR[@]}"; do
    # shellcheck disable=SC2086
    resp="$(curl_vault -f -X PUT \
      -H 'Content-Type: application/json' \
      -d "{\"key\":\"${key}\"}" \
      "${VAULT_ADDR}/v1/sys/unseal" || true)"
    if [[ -z "${resp}" ]]; then
      log "WARN: No response from /sys/unseal; will re-check sealed state."
    fi
    if ! is_sealed; then
      log "Vault is now unsealed."
      return 0
    fi
    log "Applied one unseal key; Vault still sealed. Continuing…"
    sleep 1
  done
  return 1
}

main() {
  log "vault-unseal: VAULT_ADDR=${VAULT_ADDR}"

  # Wait for Vault HTTP endpoint to be reachable
  SECS=0
  until api_up; do
    if (( SECS >= API_WAIT_SECONDS )); then
      log "ERROR: Vault API did not become reachable within ${API_WAIT_SECONDS}s."
      exit 2
    fi
    sleep "${API_WAIT_SLEEP}"
    (( SECS += API_WAIT_SLEEP ))
  done

  # If already unsealed (auto-unseal or previously unsealed), exit 0
  if ! is_sealed; then
    log "Vault is already unsealed (nothing to do)."
    exit 0
  fi

  if ! load_keys; then
    # Check if Vault is not initialized
    health_json="$(curl_vault -s "${VAULT_ADDR}/v1/sys/health" || true)"
    if [[ -z "${health_json}" ]]; then
      log "ERROR: Could not fetch Vault health to check initialization."
      exit 1
    fi
    initialized=$(echo "${health_json}" | yq -r '.initialized')
    if [[ "${initialized}" == "false" ]]; then
      log "Vault is not initialized. Initializing with key shares: 10, key threshold: 3."
      init_resp="$(curl_vault -s -X PUT -H 'Content-Type: application/json' -d '{"secret_shares":10,"secret_threshold":3}' "${VAULT_ADDR}/v1/sys/init" || true)"
      if [[ -z "${init_resp}" ]]; then
        log "ERROR: Vault initialization failed."
        exit 1
      fi
      # Save keys to /opt/vault/unseal.json
  echo "${init_resp}" > "${UNSEAL_JSON_FILE}"
  chmod 0600 "${UNSEAL_JSON_FILE}"
  log "Vault initialized. Unseal keys saved to ${UNSEAL_JSON_FILE}."
      # Try loading keys again
      if ! load_keys; then
        log "ERROR: Failed to load unseal keys after initialization."
        exit 1
      fi
    else
      log "ERROR: No unseal keys found. Provide keys via VAULT_UNSEAL_KEYS, ${UNSEAL_KEYS_FILE}, or ${UNSEAL_JSON_FILE}."
      exit 1
    fi
  fi

  if unseal_with_keys; then
    # Double-check health by parsing JSON
    health_json="$(curl_vault -s "${VAULT_ADDR}/v1/sys/health" || true)"
    if [[ -z "${health_json}" ]]; then
      log "WARN: Could not fetch Vault health after unseal."
      exit 0
    fi
    sealed=$(echo "${health_json}" | yq -r '.sealed')
    standby=$(echo "${health_json}" | yq -r '.standby')
    if [[ "${sealed}" == "false" ]]; then
      if [[ "${standby}" == "true" ]]; then
        log "Success: Vault unsealed (standby)."
      else
        log "Success: Vault unsealed (active)."
      fi
      exit 0
    else
      log "WARN: Vault still appears sealed after unseal attempt."
      exit 0
    fi
  else
    log "ERROR: Exhausted provided keys and Vault is still sealed."
    exit 3
  fi
}

main "$@"
