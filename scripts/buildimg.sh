#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2026 Schubert Anselme <schubert@anselm.es>

# MARK: Setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

setup_error_handling

# MARK: Configuration

readonly IMAGE_SOURCE="https://sanselme.github.io"
readonly REPOSITORY="ghcr.io/sanselme"
readonly TAG="${TAG:-$(git describe --tags --always 2>/dev/null | sed 's/-\([0-9][0-9]*\)-g/+\1.g/' || echo 'main')}"
readonly BUILD_PLATFORMS="linux/amd64,linux/arm64,linux/riscv64"

# MARK: Options

UPLOAD=${UPLOAD:-false}

# MARK: Build

build_image() {
  local dockerfile="$1"
  local name="$2"
  local image_tag="${REPOSITORY}/${name}:${TAG}"

  log_info "Building image: ${image_tag}"

  local build_args=(
    "buildx" "build"
    "--file" "${dockerfile}"
    "--tag" "${image_tag}"
    "--tag" "${REPOSITORY}/${name}:latest"
    "--annotation" "org.opencontainers.image.source=${IMAGE_SOURCE}"
    "--label" "org.opencontainers.image.source=${IMAGE_SOURCE}"
    "--build-arg" "VERSION=${TAG}"
    "--platform" "${BUILD_PLATFORMS}"
  )

  # Add push flag if upload is enabled
  if [[ "${UPLOAD}" == "true" ]]; then
    build_args+=("--push")
    log_info "Upload enabled - image will be pushed to registry"
  else
    log_warn "Upload disabled - image will be built locally only"
  fi

  build_args+=("${PWD}")

  # Execute docker command
  if ! docker "${build_args[@]}"; then
    log_error "Failed to build image: ${image_tag}"
    return 1
  fi

  log_info "Successfully built: ${image_tag}"

  # Sign image with cosign if uploading
  if [[ "${UPLOAD}" == "true" ]]; then
    log_info "Signing image with cosign: ${image_tag}"
    if ! cosign sign --yes "${image_tag}"; then
      log_error "Failed to sign image: ${image_tag}"
      return 1
    fi
    log_info "Successfully signed: ${image_tag}"

    # Also sign the latest tag
    log_info "Signing image with cosign: ${REPOSITORY}/${name}:latest"
    if ! cosign sign --yes "${REPOSITORY}/${name}:latest"; then
      log_error "Failed to sign image: ${REPOSITORY}/${name}:latest"
      return 1
    fi
    log_info "Successfully signed: ${REPOSITORY}/${name}:latest"
  fi
}

# MARK: Main Execution

main() {
  log_info "Starting Docker image build process"
  log_info "Repository: ${REPOSITORY}"
  log_info "Tag: ${TAG}"
  log_info "Platforms: ${BUILD_PLATFORMS}"

  # Check if docker is available
  check_dependencies docker cosign

  # Check if dockerfiles directory exists
  if [[ ! -d "build/image" ]]; then
    log_error "build/image directory not found"
    exit 1
  fi

  # If a Dockerfile argument is provided, build only that image
  if [[ $# -gt 0 && -f "$1" ]]; then
    local dockerfile="$1"
    local name
    name=$(basename "${dockerfile}" | cut -d. -f2)
    if [[ -z "${name}" ]]; then
      log_error "Unable to extract image name from ${dockerfile}"
      exit 1
    fi
    build_image "${dockerfile}" "${name}"
    log_info "Build process completed successfully (1 image processed)"
    exit 0
  fi

  # Find and process all Dockerfiles
  local dockerfile_count=0
  for dockerfile in build/image/Dockerfile*; do
    if [[ ! -f "${dockerfile}" ]]; then
      log_warn "No Dockerfiles found matching pattern: build/image/Dockerfile.*"
      continue
    fi

    local name
    name=$(basename "${dockerfile}" | cut -d. -f2)

    if [[ -z "${name}" ]]; then
      log_warn "Skipping ${dockerfile}: unable to extract name"
      continue
    fi

    build_image "${dockerfile}" "${name}"
    ((dockerfile_count++))
  done

  if [[ ${dockerfile_count} -eq 0 ]]; then
    log_error "No valid Dockerfiles processed"
    exit 1
  fi

  log_info "Build process completed successfully (${dockerfile_count} images processed)"
}

# MARK: Entrypoint

main "$@"
