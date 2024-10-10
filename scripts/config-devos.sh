#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

set -euxo pipefail

DIR="$(dirname $(realpath $(dirname "${0}")))"

# check dependencies
commands=(
  "curl"
  "git"
  "gnupg2"
  "zsh"
)

sudo apt-get update -y
for command in "${commands[@]}"; do
  if [[ -z $(command -v "${command}") ]]; then
    sudo apt-get install -y "${command}"
  fi
done

# configure permissions
groups=(
  "docker"
  "libvirt"
  "plugdev"
  "sudo"
)

for g in "${groups[@]}"; do
  sudo usermod -aG "${g}" "${USER}" || true
done

# configure environment
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  curl -fsSLo /tmp/ohmyzsh-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  bash /tmp/ohmyzsh-install.sh --unattended || true
  rm -f /tmp/ohmyzsh-install.sh
fi

ln -sf "${DIR}/config/bashrc" "${HOME}/.bashrc" || true
ln -sf "${DIR}/config/gitconfig" "${HOME}/.gitconfig" || true
ln -sf "${DIR}/config/sshconfig" "${HOME}/.ssh/config" || true
ln -sf "${DIR}/config/zshrc" "${HOME}/.zshrc" || true

sudo ln -sf "${DIR}/scripts/aliases.sh" /etc/profile.d/aliases.sh
sudo ln -sf "${DIR}/scripts/environment.sh" /etc/profile.d/environment.sh

sudo chsh -s "$(command -v zsh)" "${USER}"
