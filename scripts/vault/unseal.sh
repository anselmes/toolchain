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

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
# Extra curl flags (e.g., "--cacert /etc/ssl/myca.pem" or "--connect-timeout 2")
CURL_EXTRA=${CURL_EXTRA:-}
# How long to wait for Vault API to come up (seconds)
API_WAIT_SECONDS=${API_WAIT_SECONDS:-300}
# Sleep between retries while waiting on API
API_WAIT_SLEEP=${API_WAIT_SLEEP:-2}

UNSEAL_KEYS_FILE="${UNSEAL_KEYS_FILE:-/etc/vault/unseal-keys}"
UNSEAL_JSON_FILE="${UNSEAL_JSON_FILE:-/etc/vault/unseal.json}"

log() { printf '%s %s\n' "$(date -Is)" "$*" >&2; }

curl_vault() {
  # shellcheck disable=SC2086
  curl -sS ${CURL_EXTRA} "$@"
}

api_up() {
  curl_vault -o /dev/null -f "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1
}

is_sealed() {
  # Return 0 (true) if sealed, 1 if not sealed
  # (Don’t require jq; grep the "sealed" field from /sys/seal-status)
  local sealed
  sealed="$(curl_vault -f "${VAULT_ADDR}/v1/sys/seal-status" || true)"
  # If request failed, treat as sealed to keep retry logic simple
  if [[ -z "${sealed}" ]]; then
    return 0
  fi
  grep -q '"sealed":true' <<<"${sealed}"
}

load_keys() {
  local keys_raw=""

  if [[ -n "${VAULT_UNSEAL_KEYS:-}" ]]; then
    keys_raw="${VAULT_UNSEAL_KEYS}"
  elif [[ -f "${UNSEAL_KEYS_FILE}" ]]; then
    # One key per line, ignore blanks/comments
    keys_raw="$(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "${UNSEAL_KEYS_FILE}" | paste -sd, -)"
  elif [[ -f "${UNSEAL_JSON_FILE}" ]]; then
    # Very lenient parse: pull "unseal_keys_b64" or "unseal_keys_hex" values if present
    # Match between quotes after those field names; allow spaces.
    # This is not a full JSON parser but is good enough for Vault's init output.
    keys_raw="$(grep -oE '"unseal_keys_(b64|hex)"[[:space:]]*:[[:space:]]*\[[^]]+\]' "${UNSEAL_JSON_FILE}" \
      | head -n1 \
      | sed -E 's/.*\[(.*)\].*/\1/' \
      | tr -d '[:space:]' \
      | tr -d '"' \
      | tr ',' '\n' \
      | sed -e '/^[[:space:]]*$/d' \
      | paste -sd, -)"
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
    log "ERROR: No unseal keys found. Provide keys via VAULT_UNSEAL_KEYS, ${UNSEAL_KEYS_FILE}, or ${UNSEAL_JSON_FILE}."
    exit 1
  fi

  if unseal_with_keys; then
    # Double-check health; a sealed cluster returns 501/503, unsealed active returns 200; standby 429
    code=$(curl_vault -o /dev/null -w '%{http_code}' -s "${VAULT_ADDR}/v1/sys/health" || true)
    log "Vault health HTTP status: ${code}"
    case "${code}" in
      200|429) log "Success: Vault unsealed (active or standby)."; exit 0 ;;
      *)       log "WARN: Unexpected health code ${code}, but unseal reported success."; exit 0 ;;
    esac
  else
    log "ERROR: Exhausted provided keys and Vault is still sealed."
    exit 3
  fi
}

main "$@"
