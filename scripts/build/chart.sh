#!/bin/bash

set -eo pipefail

REGISTRY="${REGISTRY:-oci://ghcr.io/labsonline/charts}"
UPLOAD=false

BUILD_DIR=$(mktemp -d)
BUILD_ALL=true

BUILD_CLUSTERS=false
BUILD_SERVICES=false
BUILD_TEMPLATES=false
BUILD_UPSTREAM=false

SPECIFIC_CLUSTERS=()
SPECIFIC_SERVICES=()
SPECIFIC_TEMPLATES=()
SPECIFIC_UPSTREAM=()

# TODO: accept yaml configuration file to specify charts to build and upload

CLUSTERS=()

SERVICES=(
  ca
  ccm
  cni
  csi
  data
  edns
  flux
  gateway
  gwapi
  knative
  ldap
  maas
  monitoring
  msr
  netbox
  openstack
  operator
  pinniped
  vault
)

TEMPLATES=(
  ca-service-template
  cni-service-template
  crd-service-template
  csi-service-template
  data-service-template
  edns-service-template
  gateway-service-template
  gwapi-service-template
  knative-service-template
  ldap-service-template
  maas-service-template
  monitoring-service-template
  msr-service-template
  netbox-service-template
  openstack-service-template
  operator-service-template
  pinniped-service-template
  vault-service-template
)

mkdir -p "${BUILD_DIR}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      BUILD_ALL=true
      shift
      ;;
    --clusters)
      BUILD_CLUSTERS=true
      BUILD_ALL=false
      shift
      ;;
    --cluster)
      BUILD_CLUSTERS=true
      BUILD_ALL=false
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        SPECIFIC_CLUSTERS+=("$2")
        shift
      fi
      shift
      ;;
    --services)
      BUILD_SERVICES=true
      BUILD_ALL=false
      shift
      ;;
    --service)
      BUILD_SERVICES=true
      BUILD_ALL=false
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        SPECIFIC_SERVICES+=("$2")
        shift
      fi
      shift
      ;;
    --templates)
      BUILD_TEMPLATES=true
      BUILD_ALL=false
      shift
      ;;
    --template)
      BUILD_TEMPLATES=true
      BUILD_ALL=false
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        SPECIFIC_TEMPLATES+=("$2")
        shift
      fi
      shift
      ;;
    --upload)
      UPLOAD=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--all] [--upstream [name]] [--clusters] [--cluster name] [--services] [--service name] [--templates] [--template name] [--upload]"
      exit 1
      ;;
  esac
done

build() {
  local chart_path="$1"
  local output_dir="$2"

  helm dependency update "${chart_path}"
  helm lint "${chart_path}"

  # FIXME: Templating is currently disabled due to issues with charts that have
  # dependencies not present in the local environment.
  # helm template "$(basename "${chart_path}")" "${chart_path}" --include-crds >/dev/null

  helm package "${chart_path}" --destination "${output_dir}"
}

# Package charts.
if [[ "$BUILD_ALL" == true || "$BUILD_CLUSTERS" == true ]]; then
  if [[ ${#SPECIFIC_CLUSTERS[@]} -gt 0 ]]; then
    for chart in "${SPECIFIC_CLUSTERS[@]}"; do
      build "cluster/${chart}" "${BUILD_DIR}"
    done
  elif [[ "$BUILD_ALL" == true || ${#SPECIFIC_CLUSTERS[@]} -eq 0 ]]; then
    for chart in "${CLUSTERS[@]}"; do
      build "cluster/${chart}" "${BUILD_DIR}"
    done
  fi
fi

if [[ "$BUILD_ALL" == true || "$BUILD_SERVICES" == true ]]; then
  if [[ ${#SPECIFIC_SERVICES[@]} -gt 0 ]]; then
    for chart in "${SPECIFIC_SERVICES[@]}"; do
      build "service/${chart}" "${BUILD_DIR}"
    done
  elif [[ "$BUILD_ALL" == true || ${#SPECIFIC_SERVICES[@]} -eq 0 ]]; then
    for chart in "${SERVICES[@]}"; do
      build "service/${chart}" "${BUILD_DIR}"
    done
  fi
fi

if [[ "$BUILD_ALL" == true || "$BUILD_TEMPLATES" == true ]]; then
  if [[ ${#SPECIFIC_TEMPLATES[@]} -gt 0 ]]; then
    for chart in "${SPECIFIC_TEMPLATES[@]}"; do
      build "template/${chart}" "${BUILD_DIR}"
    done
  elif [[ "$BUILD_ALL" == true || ${#SPECIFIC_TEMPLATES[@]} -eq 0 ]]; then
    for chart in "${TEMPLATES[@]}"; do
      build "template/${chart}" "${BUILD_DIR}"
    done
  fi
fi

# Push charts.
if [[ "$UPLOAD" == true ]]; then
  for chart in "${BUILD_DIR}"/*.tgz; do
    [[ -f "$chart" ]] || continue
    chart_name=$(basename "${chart}" .tgz)

    # Check if this is a template chart
    is_template=false
    for template in "${TEMPLATES[@]}"; do
      if [[ "${chart_name}" == "${template}"* ]]; then
        is_template=true
        break
      fi
    done

    if [[ "${is_template}" == "true" ]]; then
      helm push "${chart}" "${REGISTRY}/servicetemplate"
    else
      helm push "${chart}" "${REGISTRY}"
    fi
  done
fi
