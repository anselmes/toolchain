#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/aliases.sh
source scripts/environment.sh

create_vm() {
  export name="${1}"
  config="${2}"

  [[ -z "${name}" ]] && echo "name is required" && exit 1
  [[ -z "${config}" ]] && echo "config is required" && exit 1
  export site_dir="$(yq '.site.dir' "${config}")"

  [[ -z "${arch}" ]] && export arch="$(uname -m)"
  case "${arch}" in
  arm64)
    export arch="aarch64"
    ;;
  *) ;;
  esac

  export $(getenv <(yq '.site.service | select(.libvirt)' "${config}") | envsubst)
  export $(getenv <(yq '.site.vm[] | select(.name == env(name))' "${config}") | envsubst)
  export vm_id="$(uuidgen)"

  if [[ -z "${vm_type}" ]]; then
    case "$(uname -s)" in
    Linux)
      export vm_type="kvm"
      [[ -z "${cpu}" ]] && export cpu="host-passthrough"
      ;;
    Darwin)
      export vm_type="hvf"
      [[ -z "${cpu}" ]] && export cpu="host-passthrough"
      ;;
    *)
      export vm_type="qemu"
      ;;
    esac
  fi

  user_data="${cloudinit_file}"
  network_config="${site_dir}/network-config"
  vm_file="${site_dir}/vm-${name}.xml"

  stat "${vm_file}" >/dev/null 2>&1 ||
    cp -f config/vm.xml "${vm_file}"

  # create cloudinit iso
  if [[ "${cloudinit_enabled}" ]]; then
    # meta-data
    printf "instance-id: ${vm_id}\nlocal-hostname: ${vm_id}\ncloud-name: nocloud\n" >/tmp/meta-data

    # network-config
    yq '.network.ethernets.oam.match.macaddress = env(networks_interfaces_oam_address_mac) |
      (.. | select(tag == "!!str")) |= envsubst
    ' config/netplan/default.yaml | tr -d '"' >"${network_config}"

    # user-data
    stat "${cloudinit_file}" >/dev/null 2>&1 ||
      printf "#cloud-config" >"${cloudinit_file}"

    if [[ -n "${libvirt_cloudinit}" ]]; then
      export vm_cloudinit="${libvirt_cloudinit}"
    else
      export vm_cloudinit="${site_dir}/cloudinit.iso"
    fi

    stat "${vm_cloudinit}" >/dev/null 2>&1 ||
      createiso "${vm_cloudinit}" /tmp/meta-data "${cloudinit_file}" "${network_config}"

    # update vm config
    yq --inplace '. |
      select(.domain.devices.disk.+@device == "cdrom").domain.devices.disk.source.+@file = env(vm_cloudinit)
    ' "${vm_file}"
  fi

  # create volume
  if [[ -n "${libvirt_images}" ]]; then
    export vol="${libvirt_images}/${name}.qcow2"
  else
    export vol="/tmp/${name}.qcow2"
  fi
  if [[ -n "${image}" ]]; then
    stat "${vol}" >/dev/null 2>&1 ||
      createvol "${vol}" "${image}"
  else
    stat "${vol}" >/dev/null 2>&1 ||
      createvol "${vol}"
  fi

  # fixme: add vcpu count
  [[ -n "${cpu}" ]] && yq --inplace '.domain.cpu.+@mode = env(cpu)' "${vm_file}" # cpu
  [[ -z "${memory}" ]] && export memory=4194304                                  # memory in kib
  if [[ "${arch}" != "x86_64" ]]; then
    # watchdog
    export vm_watchdog_model="i6300esb"
    export vm_watchdog_action="reset"
  fi

  # create vm config
  yq --inplace '
    .domain.name = env(name) |
    .domain.uuid = env(vm_id) |
    .domain.memory = env(memory) |
    .domain.devices.watchdog.+@model=env(vm_watchdog_model) |
    .domain.devices.watchdog.+@action=env(vm_watchdog_action) |
    (.. | select(tag == "!!str")) |= envsubst
  ' "${vm_file}"

  grep -q "${name}" <(virsh list --all) ||
    virsh define "${vm_file}"
}

delete_vm() {
  name="${1}"
  [[ -z "${name}" ]] && echo "name is required" && exit 1
  if grep -q "${name}" <(sudo virsh list --all); then
    sudo virsh destroy "${name}"
    sudo virsh dumpxml "${name}" | yq -p xml '.domain.os.nvram.+content' | xargs sudo rm -f -
    sudo virsh undefine --remove-all-storage "${name}"
  fi
}

case "${1}" in
--create)
  create_vm "${@:2}"
  ;;
--delete)
  delete_vm "${2}"
  ;;
*)
  echo """
Usage: ${0} [OPTIONS]

OPTIONS:
  --create <name> <config>
  --delete <name>

EXAMPLES:
  ${0} --create myvm /path/to/config.yaml
"""
  exit 1
  ;;
esac
