#!/usr/bin/env bash

set -eo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CLOUDFLARE_MODE="false"
SOURCE_FILE="$DEFAULT_SOURCE_FILE"
OUTPUT_FILE="$DEFAULT_SSH_CONFIG"

# MARK: - Help

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Generate SSH config from host YAML file for cluster access

OPTIONS:
  --src     [FILE]        Source YAML file  (default: $DEFAULT_SOURCE_FILE)
  --output  [FILE]        Output file       (default: $DEFAULT_SSH_CONFIG)
  --cloudflare            Use Cloudflare domain names instead of AWS FQDNs
  --help                  Show this help message

ENVIRONMENT VARIABLES:
  CLUSTER_NAME        Cluster name          (default: kubernetes)
  DOMAIN              DNS domain            (default: labsonline.ca)
  MKE_CONFIG_PATH     Base path for config  (default: current directory)

EXAMPLES:
  $0                                          # Generate $DEFAULT_OUTPUT_FILE from $DEFAULT_SOURCE_FILE
  $0 --src ./custom.yml                       # Use custom host file
  $0 --output ~/.ssh/mke_config               # Generate to custom output
  $0 --cloudflare                             # Use Cloudflare domain names instead of AWS FQDNs
  $0 --src ./hosts.yml --output ./out         # Custom source and output
  CLUSTER_NAME=prod $0 --output ./prod.config
EOF
}

# MARK: - Arguments

while [[ $# -gt 0 ]]; do
  case $1 in
    --src)
        SOURCE_FILE=$(parse_source_arg "$2")
        shift $([[ $# -gt 1 && ! $2 =~ ^-- ]] && echo 2 || echo 1)
        ;;
    --output)
        OUTPUT_FILE=$(parse_output_arg "$2" "$DEFAULT_SSH_CONFIG")
        shift $([[ $# -gt 1 && ! $2 =~ ^-- ]] && echo 2 || echo 1)
        ;;
    --cloudflare)
        CLOUDFLARE_MODE="true"
        shift
        ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      handle_unknown_option "$1" usage
      ;;
  esac
done

# MARK: - Validation

check_file "$SOURCE_FILE" "Source file"
validate_yaml_tools

if [[ $CLOUDFLARE_MODE == "true" ]]; then
  hostname_mode="Cloudflare domain names ($DOMAIN)"
else
  hostname_mode="AWS FQDNs"
fi

echo "Generating SSH config from source: $SOURCE_FILE"
echo "Output file: $OUTPUT_FILE"
echo "Hostname mode: $hostname_mode"

# MARK: - Main

ensure_directory "$(get_output_dir "$OUTPUT_FILE")"

# Generate SSH hosts file
HOSTS_FILE="$(get_output_dir "$OUTPUT_FILE")/hosts"
echo """# Generated SSH host entries from $SOURCE_FILE
""" > "$HOSTS_FILE"

# Extract hosts from YAML and generate SSH config entries
if [[ $CLOUDFLARE_MODE == "true" ]]; then
  yq eval '
    .spec.kubernetes.infra.hosts[] |
    "Host " + .role + "\n  HostName " + .role + ".'$DOMAIN'" + "\n"
  ' "$SOURCE_FILE" >> "$HOSTS_FILE"
else
  yq eval '
    .spec.kubernetes.infra.hosts[] |
    "Host " + .role + "\n  HostName " + .fqdn + "\n"
  ' "$SOURCE_FILE" >> "$HOSTS_FILE"
fi

# MARK: - Summary

ABSOLUTE_HOSTS_FILE=$(realpath "$HOSTS_FILE")
cat > "$OUTPUT_FILE" << EOF
Include $ABSOLUTE_HOSTS_FILE

Host *
  # note: ignored
  IgnoreUnknown UseKeychain

  # note: config
  AddKeysToAgent yes
  ForwardAgent yes
  IdentitiesOnly yes
  IdentityFile ${MKE_CONFIG_PATH}/config/ssh/${CLUSTER_NAME}-ssh-key.pem
  PasswordAuthentication no
  StrictHostKeyChecking no
  UpdateHostKeys no
  UseKeychain yes
  User ubuntu
  UserKnownHostsFile /dev/null

EOF

echo """
SSH config generated successfully!
  Source: $SOURCE_FILE
  Output: $OUTPUT_FILE
  Hosts:  $HOSTS_FILE

  Hostname Mode: $hostname_mode

  MKE_CONFIG_PATH: $MKE_CONFIG_PATH
  CLUSTER_NAME: $CLUSTER_NAME

To use this SSH config, add the following to your ~/.ssh/config:

  Include $(realpath $OUTPUT_FILE)

This include should be placed at the top of ~/.ssh/config or after
any existing includes in the top section.
"""
