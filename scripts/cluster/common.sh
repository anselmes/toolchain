#!/usr/bin/env bash

# MARK: - Constants

# Default environment variables
export CLUSTER_NAME="${CLUSTER_NAME:-kubernetes}"
export DOMAIN="${DOMAIN:-mirantis.labsonline.ca}"
export MKE_CONFIG_PATH="${MKE_CONFIG_PATH:-$(pwd)}"

# Default file paths
DEFAULT_SOURCE_FILE="hack/host.yaml"
DEFAULT_TERRAFORM_DIR="modules/terraform"
DEFAULT_ANSIBLE_DIR="modules/ansible"
DEFAULT_OUTPUT_DIR="$DEFAULT_ANSIBLE_DIR/group_vars"
DEFAULT_INVENTORY_FILE="$DEFAULT_ANSIBLE_DIR/inventory.yml"
DEFAULT_SSH_CONFIG="config/ssh/config"

# MARK: - Validation Functions

check_command() {
  local cmd=$1
  local install_msg=${2:-""}

  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd is required"
    if [[ -n "$install_msg" ]]; then
      echo "$install_msg"
    fi
    return 1
  fi
  return 0
}

check_file() {
  local file=$1
  local description=${2:-"File"}

  if [[ ! -f "$file" ]]; then
    echo "Error: $description '$file' not found"
    return 1
  fi
  return 0
}

check_directory() {
  local dir=$1
  local description=${2:-"Directory"}

  if [[ ! -d "$dir" ]]; then
    echo "Error: $description '$dir' not found"
    return 1
  fi
  return 0
}

validate_yaml_tools() {
  check_command "yq" "Install with: brew install yq"
}

validate_terraform_tools() {
  check_command "terraform" "Install from: https://www.terraform.io/downloads.html"
}

validate_cloudflare_tools() {
  if [[ -z "$CF_API_TOKEN" ]]; then
    echo "Error: CF_API_TOKEN environment variable is required for Cloudflare operations"
    echo "Get your API token from: https://dash.cloudflare.com/profile/api-tokens"
    return 1
  fi

  check_command "curl" "Install curl"
}

validate_docker_tools() {
  check_command "docker" "Install from: https://docs.docker.com/get-docker/"

  # Check if Docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker and try again."
    return 1
  fi
  return 0
}

# MARK: - YAML Processing Functions

get_available_hosts() {
  local role_prefix=$1
  local source_file=$2

  # Get all roles that match the prefix pattern using grep
  yq '.spec.kubernetes.infra.hosts[].role' "$source_file" -r | grep "^${CLUSTER_NAME}-${role_prefix}-" || true
}

extract_host_info() {
  local role_name=$1
  local source_file=$2
  local output_type=${3:-"fqdn"}
  local cloudflare_mode=${4:-"false"}

  if [[ "$cloudflare_mode" == "true" ]]; then
    # Use Cloudflare domain format: role.domain
    echo "${role_name}.${DOMAIN}"
  elif [[ "$output_type" == "fqdn" ]]; then
    # Use AWS FQDN from YAML
    yq "
      .spec.kubernetes.infra.hosts |
      map(select(.role == \"$role_name\")) |
      .[0].fqdn // \"null\"
    " "$source_file"
  else
    # Use IP address from YAML
    yq "
      .spec.kubernetes.infra.hosts |
      map(select(.role == \"$role_name\")) |
      .[0].ssh.address // \"null\"
    " "$source_file"
  fi
}

get_ssh_key_path() {
  local role_name=$1
  local source_file=$2

  yq "
    .spec.kubernetes.infra.hosts |
    map(select(.role == \"$role_name\")) |
    .[0].ssh.keyPath // \"null\"
  " "$source_file"
}

get_ssh_user() {
  local role_name=$1
  local source_file=$2

  yq "
    .spec.kubernetes.infra.hosts |
    map(select(.role == \"$role_name\")) |
    .[0].ssh.user // \"ubuntu\"
  " "$source_file"
}

get_ssh_port() {
  local role_name=$1
  local source_file=$2

  yq "
    .spec.kubernetes.infra.hosts |
    map(select(.role == \"$role_name\")) |
    .[0].ssh.port // \"22\"
  " "$source_file"
}

# MARK: - Directory and File Management

ensure_directory() {
  local dir=$1
  mkdir -p "$dir"
}

get_output_dir() {
  local file_path=$1
  dirname "$file_path"
}

# MARK: - Group Variables Detection

detect_host_variable() {
  local group_name=$1
  local group_vars_dir=${2:-"$DEFAULT_OUTPUT_DIR"}
  local group_vars_file="$group_vars_dir/${group_name}.yml"

  if [[ -f "$group_vars_file" ]]; then
    if grep -q "host_fqdns:" "$group_vars_file" 2>/dev/null; then
      echo "host_fqdns"
    elif grep -q "host_ips:" "$group_vars_file" 2>/dev/null; then
      echo "host_ips"
    else
      echo "none"
    fi
  else
    echo "none"
  fi
}

# MARK: - Argument Parsing Helpers

parse_source_arg() {
  local next_arg=${1:-}
  local default_file=${2:-$DEFAULT_SOURCE_FILE}

  if [[ -n "$next_arg" && ! "$next_arg" =~ ^-- ]]; then
    echo "$next_arg"
  else
    echo "$default_file"
  fi
}

parse_output_arg() {
  local next_arg=${1:-}
  local default_output=${2:-}

  if [[ -n "$next_arg" && ! "$next_arg" =~ ^-- ]]; then
    echo "$next_arg"
  else
    echo "$default_output"
  fi
}

# MARK: - Output Formatting

print_section() {
  local title=$1
  echo ""
  echo "=== $title ==="
}

print_result() {
  local description=$1
  shift
  local details=("$@")

  echo ""
  echo "$description"
  for detail in "${details[@]}"; do
    echo "  $detail"
  done
}

print_host_counts() {
  local cp_count=$1
  local md_count=$2
  local msr_count=$3
  local cp_hosts=("${@:4:$cp_count}")
  local md_hosts=("${@:$((4+cp_count)):$md_count}")
  local msr_hosts=("${@:$((4+cp_count+md_count)):$msr_count}")

  echo "Host counts:"
  echo "  Managers: $cp_count (${cp_hosts[*]})"
  echo "  Nodes: $md_count (${md_hosts[*]})"
  echo "  MSR Nodes: $msr_count (${msr_hosts[*]})"
}

# MARK: - Terraform Helpers

terraform_exec() {
  local terraform_dir=$1
  local cmd=$2

  (cd "$terraform_dir" && eval "$cmd")
}

get_terraform_output() {
  local terraform_dir=$1
  local output_name=$2

  terraform_exec "$terraform_dir" "terraform output -raw $output_name 2>/dev/null || echo ''"
}

# MARK: - DNS Resolution

resolve_to_ip() {
  local hostname=$1

  if [[ -z "$hostname" ]]; then
    echo ""
    return
  fi

  local ip=$(dig +short "$hostname" | head -1)
  echo "${ip:-}"
}

# MARK: - Common Usage Patterns

handle_help_option() {
  local option=$1
  local usage_func=$2

  case $option in
    --help|-h)
      $usage_func
      exit 0
      ;;
  esac
}

handle_unknown_option() {
  local option=$1
  local usage_func=$2

  echo "Unknown option: $option"
  $usage_func
  exit 1
}
