#!/bin/bash

configure_system() {
  local locale="${1:-C.UTF-8}"
  local timezone="${2:-America/Toronto}"

  set -eux

  # disable swap
  swapoff -a && sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

  # set locale
  localectl set-locale LANG="${locale}"

  # set timezone
  timedatectl set-ntp true
  timedatectl set-timezone "${timezone}"
}

# If script is run directly (not sourced), call the function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  configure_system "$@"
fi
