#!/bin/bash
set -euo pipefail

DOMAIN_NAME="${DOMAIN_NAME:-svc.local}"
IPv4_ADDR=$(ip -br addr show eth0 | awk '{ print $3 }' | cut -d / -f 1)

# configure dnsmasq
systemctl enable dnsmasq
echo "address=/${DOMAIN_NAME}/${IPv4_ADDR}" >/etc/dnsmasq.d/svc.conf
systemctl restart dnsmasq

# add flag (not present by default): --service-node-port-range=1-32767
# wait for kubeadm to generate the static pod manifest before patching it
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
until [[ -f "${MANIFEST}" ]]; do sleep 1; done
grep -q -- --service-node-port-range "${MANIFEST}" ||
  sed -i "s/--advertise-address=${IPv4_ADDR}/&\n    - --service-node-port-range=1-32767/" "${MANIFEST}"
