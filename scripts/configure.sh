#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

source scripts/aliases.sh
source scripts/environment.sh

# dependencies
if [[ -n $(command -v "apt-get") ]]; then
  commands=(
    "curl"
    "git"
    "gnupg2"
    "shfmt"
    "zsh"
  )

  for command in "${commands[@]}"; do
    if ! grep -qa "${command}" <(apt list --installed); then
      sudo apt-get update -yq
      sudo apt-get install -y "${command}"
    fi
  done
fi

# permissions
if [[ -n $(command -v "usermod") ]]; then
  groups=(
    "docker"
    "libvirt"
    "plugdev"
    "sudo"
  )

  # note: always set the user to "devcontainer" if it exists
  if [[ "devcontainer" == "$(whoami)" ]]; then
    USER="devcontainer"
  else
    USER="$(whoami)"
  fi

  for g in "${groups[@]}"; do
    sudo usermod -aG "${g}" "${USER}"
  done

  id "${USER}"
fi

# environment
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  curl -fsSLo /tmp/ohmyzsh-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  bash /tmp/ohmyzsh-install.sh --unattended || true
  rm -f /tmp/ohmyzsh-install.sh
fi

ln -sf \
  modules/dotfiles/.bashrc \
  modules/dotfiles/.zshrc \
  modules/dotfiles/.commitlintrc \
  modules/dotfiles/.idea \
  modules/dotfiles/.vscode \
  .trunk/configs/.* \
  .

ITEMS=(
  "modules/dotfiles/.devcontainer"
  "modules/dotfiles/.editorconfig"
  "modules/dotfiles/.gitignore"
  "modules/dotfiles/.ssh"
  "modules/dotfiles/.trunk"
  "modules/dotfiles/compose-dev.yaml"
)
for ITEM in "${ITEMS[@]}"; do
  # copy if not present in the root directory
  ls -l $(basename "${ITEM}") >/dev/null 2>&1 || cp -r "${ITEM}" .
done

sudo chsh -s "$(command -v zsh)" "${USER}"

# trunk.io
if [[ -n $(command -v "trunk") ]]; then
  trunk fmt
  trunk check
fi
