#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2026 Schubert Anselme <schubert@anselm.es>


# MARK: Colors

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# MARK: Logging

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1" >&2
}

# MARK: Validation

check_command() {
  local cmd="$1"
  if ! command -v "${cmd}" &> /dev/null; then
    log_error "Required command '${cmd}' not found in PATH"
    return 1
  fi
  return 0
}

check_dependencies() {
  local deps=("$@")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! check_command "${dep}"; then
      missing+=("${dep}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing[*]}"
    exit 1
  fi
}

# MARK: Utility

escape_str() {
  echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

cleanup_temp() {
  local temp_dir="$1"
  if [[ -n "${temp_dir}" && -d "${temp_dir}" ]]; then
    rm -rf "${temp_dir}"
  fi
}

# MARK: Error Handling

setup_error_handling() {
  set -euo pipefail
  trap 'log_error "Script failed on line $LINENO"' ERR
}
