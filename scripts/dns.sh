#!/usr/bin/env bash

set -eo pipefail

DEFAULT_TERRAFORM_DIR="modules/terraform"
DEFAULT_OUTPUT_FILE="../../hack/${CLUSTER_NAME}.${DOMAIN}.txt"

CLUSTER_NAME="${CLUSTER_NAME:-kubernetes}"
DOMAIN="${DOMAIN:-labsonline.ca}"

CLOUDFLARE_MODE="false"

RECORD_TYPE="fqdn"
PROXY="false"

OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
TERRAFORM_DIR="$DEFAULT_TERRAFORM_DIR"

# MARK: - Help

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Generate DNS records from Terraform output for Cloudflare/bind9 import

OPTIONS:
  --terraform [DIR]       Terraform directory                 (default: $DEFAULT_TERRAFORM_DIR)
  --ip                    Generate A records using IP addresses
  --fqdn                  Generate CNAME records using FQDNs  (default)
  --proxy                 Enable Cloudflare proxy             (cf-proxied:true)
  --cloudflare            Create/update records via Cloudflare API
  --output    [FILE]      Output file                         (default: $DEFAULT_OUTPUT_FILE)
  --help                  Show this help message

ENVIRONMENT VARIABLES:
  CLUSTER_NAME        Cluster name (default: kubernetes)
  DOMAIN              DNS domain (default: labsonline.ca)
  CF_API_TOKEN        Cloudflare API token (required for --cloudflare)
  CF_ZONE_ID          Cloudflare Zone ID (auto-detected if not provided)

EXAMPLES:
  $0                                  # Generate CNAME records from terraform/
  $0 --terraform ./tf                 # Use custom terraform directory
  $0 --ip                             # Generate A records instead of CNAME
  $0 --proxy                          # Generate proxied records
  $0 --cloudflare --proxy             # Create proxied records via Cloudflare API
  $0 --output custom.txt              # Use custom output file
  DOMAIN=example.com $0 --ip --proxy  # Custom domain with proxied A records
EOF
}

# MARK: - Arguments

while [[ $# -gt 0 ]]; do
  case $1 in
    --terraform)
      if [[ $# -gt 1 && ! $2 =~ ^-- ]]; then  # Check if next argument exists and doesn't start with --
        TERRAFORM_DIR="$2"
        shift 2
      else
        TERRAFORM_DIR="$DEFAULT_TERRAFORM_DIR"
        shift
      fi
      ;;
    --ip)
      RECORD_TYPE="ip"
      shift
      ;;
    --fqdn)
      RECORD_TYPE="fqdn"
      shift
      ;;
    --proxy)
      PROXY="true"
      shift
      ;;
    --cloudflare)
      CLOUDFLARE_MODE="true"
      shift
      ;;
    --output)
      if [[ $# -gt 1 && ! $2 =~ ^-- ]]; then  # Check if next argument exists and doesn't start with --
        OUTPUT_FILE="$2"
        shift 2
      else
        OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
        shift
      fi
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# MARK: - Validation

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  echo "Error: Terraform directory '$TERRAFORM_DIR' not found"
  exit 1
fi

if ! command -v terraform &> /dev/null; then
  echo "Error: terraform is required"
  echo "Install from: https://www.terraform.io/downloads.html"
  exit 1
fi

if ! command -v yq &> /dev/null; then
  echo "Error: yq is required to parse YAML output"
  echo "Install with: brew install yq"
  exit 1
fi

# Validate Cloudflare credentials if needed
if [[ $CLOUDFLARE_MODE == "true" ]]; then
  if [[ -z "$CF_API_TOKEN" ]]; then
    echo "Error: CF_API_TOKEN environment variable is required for Cloudflare mode"
    echo "Get your API token from: https://dash.cloudflare.com/profile/api-tokens"
    exit 1
  fi

  if ! command -v curl &> /dev/null; then
    echo "Error: curl is required for Cloudflare API calls"
    exit 1
  fi
fi

# MARK: - Functions

get_zone_id() {
  if [[ -n "$CF_ZONE_ID" ]]; then
    echo "$CF_ZONE_ID"
    return 0
  fi

  # Extract root domain from DOMAIN (e.g., mirantis.labsonline.ca -> labsonline.ca)
  local root_domain
  if [[ "$DOMAIN" =~ \.[^.]+\.[^.]+$ ]]; then
    # Extract the last two parts (domain.tld)
    root_domain=$(echo "$DOMAIN" | sed -E 's/.*\.([^.]+\.[^.]+)$/\1/')
  else
    # Already a root domain
    root_domain="$DOMAIN"
  fi

  local response
  response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$root_domain" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

  local zone_id
  zone_id=$(echo "$response" | yq eval '.result[0].id // null' -p json -)

  if [[ -z "$zone_id" || "$zone_id" == "null" ]]; then
    echo "Error: Could not find zone ID for domain: $root_domain" >&2
    echo "Available zones:" >&2
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" | \
      yq eval '.result[].name' -p json - >&2
    return 1
  fi

  echo "$zone_id"
}

get_existing_record() {
  local zone_id="$1"
  local name="$2"
  local record_type="$3"

  curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$name&type=$record_type" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | \
    yq eval '.result[0].id // null' -p json -
}

create_cloudflare_record() {
  local zone_id="$1"
  local name="$2"
  local record_type="$3"
  local content="$4"
  local proxied="$5"


  local response
  response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"$record_type\",
      \"name\":\"$name\",
      \"content\":\"$content\",
      \"proxied\":$proxied,
      \"ttl\":1
    }")


  local success
  success=$(echo "$response" | yq eval '.success // false' -p json -)

  if [[ "$success" == "true" ]]; then
    echo "✓ Created $record_type record: $name -> $content"
    return 0
  else
    local error_msg
    error_msg=$(echo "$response" | yq eval '.errors[0].message // "Unknown error"' -p json -)
    echo "✗ Failed to create $record_type record: $name -> $content ($error_msg)"
    echo "   Response: $response" >&2
    return 1
  fi
}

update_cloudflare_record() {
  local zone_id="$1"
  local record_id="$2"
  local name="$3"
  local record_type="$4"
  local content="$5"
  local proxied="$6"

  local response
  response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"$record_type\",
      \"name\":\"$name\",
      \"content\":\"$content\",
      \"proxied\":$proxied,
      \"ttl\":1
    }")

  local success
  success=$(echo "$response" | yq eval '.success // false' -p json -)

  if [[ "$success" == "true" ]]; then
    echo "✓ Updated $record_type record: $name -> $content"
    return 0
  else
    local error_msg
    error_msg=$(echo "$response" | yq eval '.errors[0].message // "Unknown error"' -p json -)
    echo "✗ Failed to update $record_type record: $name -> $content ($error_msg)"
    echo "   Response: $response" >&2
    return 1
  fi
}

create_or_update_cloudflare_record() {
  local zone_id="$1"
  local hostname="$2"
  local record_type="$3"
  local content="$4"
  local proxied="$5"

  local full_name="$hostname.$DOMAIN"
  local existing_record_id

  existing_record_id=$(get_existing_record "$zone_id" "$full_name" "$record_type")

  if [[ -n "$existing_record_id" && "$existing_record_id" != "null" ]]; then
    update_cloudflare_record "$zone_id" "$existing_record_id" "$full_name" "$record_type" "$content" "$proxied"
  else
    create_cloudflare_record "$zone_id" "$full_name" "$record_type" "$content" "$proxied"
  fi
}

handle_loadbalancer_records() {
  local cluster_file="/tmp/cluster_node.yaml"
  local mke_lb_file="/tmp/mke_lb_info.yaml"
  local msr_lb_file="/tmp/msr_lb_info.yaml"

  echo "Processing load balancer records..."

  if [[ ! -f "$cluster_file" ]]; then
    echo "Warning: No cluster configuration found at $cluster_file"
    return 1
  fi

  # Check for load balancer outputs first
  local mke_lb_dns_name msr_lb_dns_name
  mke_lb_dns_name=""
  msr_lb_dns_name=""

  if [[ -f "$mke_lb_file" ]]; then
    mke_lb_dns_name=$(yq eval '.spec.dns_name // ""' "$mke_lb_file" 2>/dev/null || echo "")
  fi

  if [[ -f "$msr_lb_file" ]]; then
    msr_lb_dns_name=$(yq eval '.spec.dns_name // ""' "$msr_lb_file" 2>/dev/null || echo "")
  fi

  if [[ -n "$mke_lb_dns_name" && "$mke_lb_dns_name" != "null" ]] || [[ -n "$msr_lb_dns_name" && "$msr_lb_dns_name" != "null" ]]; then
    echo "Found dedicated load balancer configuration"

    # Process MKE load balancer if it exists
    if [[ -n "$mke_lb_dns_name" && "$mke_lb_dns_name" != "null" ]]; then
      echo "Creating MKE load balancer record pointing to $mke_lb_dns_name"
      generate_lb_record "mke" "" "$mke_lb_dns_name"
    fi

    # Process MSR load balancer if it exists
    if [[ -n "$msr_lb_dns_name" && "$msr_lb_dns_name" != "null" ]]; then
      echo "Creating MSR load balancer record pointing to $msr_lb_dns_name"
      generate_lb_record "msr" "" "$msr_lb_dns_name"
    fi
  else
    echo "No dedicated load balancer found, using single node setup"

    # Use first control plane node for MKE
    local mke_ip mke_fqdn
    mke_ip=$(yq eval '.spec.kubernetes.infra.hosts[] | select(.role == "kubernetes-cp-0") | .ssh.address // ""' "$cluster_file" 2>/dev/null || echo "")
    mke_fqdn=$(yq eval '.spec.kubernetes.infra.hosts[] | select(.role == "kubernetes-cp-0") | .fqdn // ""' "$cluster_file" 2>/dev/null || echo "")

    if [[ -n "$mke_ip" || -n "$mke_fqdn" ]]; then
      echo "Creating MKE load balancer record pointing to $mke_fqdn"
      generate_lb_record "mke" "$mke_ip" "$mke_fqdn"
    else
      echo "Warning: No control plane node found for MKE load balancer"
    fi

    # Use first MSR node for MSR
    local msr_ip msr_fqdn
    msr_ip=$(yq eval '.spec.kubernetes.infra.hosts[] | select(.role == "kubernetes-msr-0") | .ssh.address // ""' "$cluster_file" 2>/dev/null || echo "")
    msr_fqdn=$(yq eval '.spec.kubernetes.infra.hosts[] | select(.role == "kubernetes-msr-0") | .fqdn // ""' "$cluster_file" 2>/dev/null || echo "")

    if [[ -n "$msr_ip" || -n "$msr_fqdn" ]]; then
      echo "Creating MSR load balancer record pointing to $msr_fqdn"
      generate_lb_record "msr" "$msr_ip" "$msr_fqdn"
    else
      echo "Warning: No MSR node found for MSR load balancer"
    fi
  fi
}

generate_a_record() {
  local hostname="$1"
  local ip="$2"
  printf "%-50s\t1\tIN\tA\t%-15s ; cf_tags=cf-proxied:%s\n" "$hostname.$DOMAIN." "$ip" "$PROXY"
}

generate_cname_record() {
  local hostname="$1"
  local target="$2"
  printf "%-50s\t1\tIN\tCNAME\t%s ; cf_tags=cf-proxied:%s\n" "$hostname.$DOMAIN." "$target." "$PROXY"
}

generate_lb_record() {
  local service="$1"
  local ip="$2"
  local fqdn="$3"
  local hostname="$service"

  if [[ $RECORD_TYPE == "ip" && -n "$ip" ]]; then
    if [[ $CLOUDFLARE_MODE == "true" ]]; then
      create_or_update_cloudflare_record "$ZONE_ID" "$hostname" "A" "$ip" "$PROXY"
    else
      generate_a_record "$hostname" "$ip" >> "$OUTPUT_FILE"
    fi
  elif [[ $RECORD_TYPE == "fqdn" && -n "$fqdn" ]]; then
    if [[ $CLOUDFLARE_MODE == "true" ]]; then
      create_or_update_cloudflare_record "$ZONE_ID" "$hostname" "CNAME" "$fqdn" "$PROXY"
    else
      generate_cname_record "$hostname" "$fqdn" >> "$OUTPUT_FILE"
    fi
  fi
}

# MARK: - Main

if [[ $RECORD_TYPE == "ip" ]]; then
  record_type_display="A (IP)"
  record_type_comment="A records (IP addresses)"
else
  record_type_display="CNAME (FQDN)"
  record_type_comment="CNAME records (FQDNs)"
fi

proxy_mode_display="disabled"
if [[ $PROXY == "true" ]]; then
  proxy_mode_display="enabled"
fi

output_mode="file"
if [[ $CLOUDFLARE_MODE == "true" ]]; then
  output_mode="Cloudflare API"
fi

echo """
Generating DNS records from Terraform output: $TERRAFORM_DIR
Record Type: $record_type_display
Proxy Mode: $proxy_mode_display
Output Mode: $output_mode
Output File: $OUTPUT_FILE
"""

# Initialize Cloudflare if needed
if [[ $CLOUDFLARE_MODE == "true" ]]; then
  echo "Initializing Cloudflare API..."

  ZONE_ID=$(get_zone_id)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  echo "Zone ID: $ZONE_ID"
  echo ""
fi

# Get terraform output
{
  cd "$TERRAFORM_DIR"
  if ! terraform output -raw cluster_node | yq eval '.' - > /tmp/cluster_node.yaml 2>/dev/null; then
    echo "Error: Failed to get terraform output. Make sure terraform has been applied."
    exit 1
  fi

  # Get load balancer info if available
  terraform output -raw mke_lb_info > /tmp/mke_lb_info.yaml 2>/dev/null || echo "null" > /tmp/mke_lb_info.yaml
  terraform output -raw msr_lb_info > /tmp/msr_lb_info.yaml 2>/dev/null || echo "null" > /tmp/msr_lb_info.yaml
}

# Generate DNS records
if [[ $CLOUDFLARE_MODE == "false" ]]; then
  > "$OUTPUT_FILE"
fi

# Parse hosts from the YAML content
yq eval '
  .spec.kubernetes.infra.hosts[] |
  .role + "|" + (.ssh.address // "") + "|" + (.fqdn // "")
' /tmp/cluster_node.yaml | while IFS='|' read -r role ip fqdn; do
  if [[ -n "$role" ]]; then
    # Use role as hostname (already formatted correctly)
    hostname="$role"

    if [[ $RECORD_TYPE == "ip" && -n "$ip" ]]; then
      if [[ $CLOUDFLARE_MODE == "true" ]]; then
        create_or_update_cloudflare_record "$ZONE_ID" "$hostname" "A" "$ip" "$PROXY"
      else
        generate_a_record "$hostname" "$ip" >> "$OUTPUT_FILE"
      fi
    elif [[ $RECORD_TYPE == "fqdn" && -n "$fqdn" ]]; then
      if [[ $CLOUDFLARE_MODE == "true" ]]; then
        create_or_update_cloudflare_record "$ZONE_ID" "$hostname" "CNAME" "$fqdn" "$PROXY"
      else
        generate_cname_record "$hostname" "$fqdn" >> "$OUTPUT_FILE"
      fi
    fi
  fi
done

# Handle load balancer records
handle_loadbalancer_records

if [[ $CLOUDFLARE_MODE == "false" ]]; then
  echo "" >> "$OUTPUT_FILE"
fi

# MARK: - Summary

if [[ $CLOUDFLARE_MODE == "true" ]]; then
  echo """

DNS records processed via Cloudflare API!
  Terraform Dir: $TERRAFORM_DIR
  Record Type: $record_type_display
  Proxy Mode: $proxy_mode_display
  Cluster: $CLUSTER_NAME
  Domain: $DOMAIN
  Zone ID: $ZONE_ID

Records have been created/updated in your Cloudflare DNS zone.
"""
else
  echo """

DNS records generated successfully!
  Terraform Dir: $TERRAFORM_DIR
  Output: $OUTPUT_FILE
  Record Type: $record_type_display
  Proxy Mode: $proxy_mode_display
  Cluster: $CLUSTER_NAME
  Domain: $DOMAIN

To import into Cloudflare:
  1. Go to your domain's DNS settings
  2. Click 'Import DNS records'
  3. Upload the file: $OUTPUT_FILE

To import into bind9:
  1. Include the file in your zone configuration
  2. Reload the zone: sudo rndc reload

Or use --cloudflare flag to create records directly via API.
"""
fi
