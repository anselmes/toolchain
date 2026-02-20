#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2026 Schubert Anselme <schubert@anselm.es>

# Generate Swagger UI from swagger.json files
# ref: https://github.com/johanbrandhorst/grpc-gateway-boilerplate/blob/main/scripts/generate-swagger-ui.sh

# MARK: Setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

setup_error_handling

# MARK: Configuration

readonly CACHE_DIR=".cache/swagger-ui"
readonly OUTPUT_DIR="pkg/gateway/ui"
readonly SWAGGER_UI_REPO="https://github.com/swagger-api/swagger-ui.git"
readonly SWAGGER_UI_VERSION="${1:-v5.18.2}"

# MARK: Validation

validate_version() {
  if [[ -z "${SWAGGER_UI_VERSION}" ]]; then
    log_error "Missing Swagger UI version"
    echo "Usage: $0 [version]" >&2
    echo "Example: $0 v5.18.2" >&2
    exit 1
  fi
  log_info "Using Swagger UI version: ${SWAGGER_UI_VERSION}"
}

# MARK: Cache Management

setup_cache() {
  log_step "Setting up Swagger UI cache"

  if [[ -d "${CACHE_DIR}" ]]; then
    log_info "Cache directory exists: ${CACHE_DIR}"
    return 0
  fi

  log_info "Creating cache directory: ${CACHE_DIR}"
  mkdir -p "${CACHE_DIR}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  log_info "Cloning Swagger UI repository (${SWAGGER_UI_VERSION})"
  if ! git clone --depth 1 --branch "${SWAGGER_UI_VERSION}" "${SWAGGER_UI_REPO}" "${tmp_dir}" &> /dev/null; then
    log_error "Failed to clone Swagger UI repository"
    cleanup_temp "${tmp_dir}"
    exit 1
  fi

  log_info "Copying Swagger UI files to cache"
  cp -r "${tmp_dir}/dist/"* "${CACHE_DIR}/"
  cp -r "${tmp_dir}/LICENSE" "${CACHE_DIR}/"

  # Cleanup
  cleanup_temp "${tmp_dir}"
  log_info "Swagger UI cached successfully"
}

# MARK: Swagger JSON Processing

generate_urls_config() {
  log_step "Generating URLs configuration from swagger.json files"

  local urls_config="    urls: ["
  local found_files=0
  local escaped_output_dir
  escaped_output_dir="$(escape_str "${OUTPUT_DIR}/")"

  # Find all swagger.json files
  while IFS= read -r -d '' swagger_file; do
    local path="${swagger_file//${escaped_output_dir}/}"
    local name="${path##*/}"
    local version="${path%%/*}"
    name="${name%.swagger.json}"

    # Capitalize first letter for display name
    name="$(tr '[:lower:]' '[:upper:]' <<< "${name:0:1}")${name:1}"
    # Append version suffix for grouped API docs (e.g. "Todo (v1)").
    if [[ "${version}" =~ ^v[0-9]+$ ]]; then
      name="${name} (${version})"
    fi

    urls_config="${urls_config}{\"url\":\"${path}\",\"name\":\"${name}\"},"
    log_info "Found swagger file: ${path} -> ${name}"
    ((found_files++))
  done < <(find "${OUTPUT_DIR}" -name "*.swagger.json" -print0 2>/dev/null || true)

  if [[ ${found_files} -eq 0 ]]; then
    log_warn "No swagger.json files found in ${OUTPUT_DIR}"
    # Return default config
    echo "    urls: [{\"url\":\"v1/todo.swagger.json\",\"name\":\"Todo (v1)\"}],"
    return
  fi

  # Remove trailing comma and close array
  urls_config="${urls_config%,}],"
  echo "${urls_config}"

  log_info "Generated configuration for ${found_files} swagger files"
}

# MARK: UI Generation

copy_swagger_ui() {
  log_step "Copying Swagger UI files to output directory"

  # Ensure output directory exists
  mkdir -p "${OUTPUT_DIR}"

  # Copy all cached files
  cp -r "${CACHE_DIR}/"* "${OUTPUT_DIR}/"

  log_info "Swagger UI files copied to: ${OUTPUT_DIR}"
}

update_initializer() {
  local urls_config="$1"
  local initializer_file="${OUTPUT_DIR}/swagger-initializer.js"

  log_step "Updating swagger-initializer.js with generated URLs"

  if [[ ! -f "${initializer_file}" ]]; then
    log_error "swagger-initializer.js not found: ${initializer_file}"
    exit 1
  fi

  # Find the line containing "url" configuration
  local line_number
  line_number="$(grep -n "url" "${initializer_file}" | head -1 | cut -f1 -d: || true)"

  if [[ -z "${line_number}" ]]; then
    log_error "Could not find URL configuration line in ${initializer_file}"
    exit 1
  fi

  # Escape the replacement string for sed
  local escaped_config
  escaped_config="$(escape_str "${urls_config}")"

  # Replace the line
  sed -i."$(date +%s)" -e "${line_number} s/^.*$/${escaped_config}/" "${initializer_file}"

  # Remove backup file
  rm -f "${initializer_file}."*

  log_info "Updated swagger-initializer.js (line ${line_number})"
}

# MARK: Main Execution

main() {
  log_info "Starting Swagger UI generation process"

  # Validate inputs and dependencies
  validate_version
  check_dependencies git sed find

  # Setup environment
  setup_cache

  # Generate configuration
  local urls_config
  urls_config="$(generate_urls_config)"

  # Copy UI files and update configuration
  copy_swagger_ui
  update_initializer "${urls_config}"

  log_info "Swagger UI generation completed successfully"
  log_info "Output directory: ${OUTPUT_DIR}"
}

# MARK: Entrypoint

main "$@"
