#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

DIR="$(dirname $(realpath $(dirname "${0}")))"
source "${DIR}/scripts/aliases.sh"
source "${DIR}/scripts/environment.sh"

# dependencies
if [[ -n $(command -v "apt-get") ]]; then
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
fi

# permissions
if [[ -n $(command -v "usermod") ]]; then
  groups=(
    "docker"
    "libvirt"
    "plugdev"
    "sudo"
  )

  for g in "${groups[@]}"; do
    sudo usermod -aG "${g}" "${USER}" || true
  done
fi

# environment
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  curl -fsSLo /tmp/ohmyzsh-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  bash /tmp/ohmyzsh-install.sh --unattended || true
  rm -f /tmp/ohmyzsh-install.sh
fi

ln -sf \
  "${DIR}/modules/dotfiles/.bashrc" \
  "${DIR}/modules/dotfiles/.zshrc" \
  "${DIR}/modules/dotfiles/.editorconfig" \
  "${DIR}/modules/dotfiles/.commitlintrc" \
  "${DIR}/modules/dotfiles/.idea" \
  "${DIR}/modules/dotfiles/.vscode" \
  "${DIR}/.trunk/configs/."* \
  "${DIR}"

for ITEM in $(echo """
${DIR}/modules/dotfiles/.devcontainer
${DIR}/modules/dotfiles/.gitignore
${DIR}/modules/dotfiles/.ssh
${DIR}/modules/dotfiles/.trunk
${DIR}/modules/dotfiles/compose-dev.yaml
"""); do
  # copy if not present in "${DIR}"
  ls -l $(basename "${ITEM}") > /dev/null 2>&1 || cp -r "${ITEM}" "${DIR}/"
done

sudo chsh -s "$(command -v zsh)" "${USER}"

# trunk.io
if [[ -n $(command -v "usermod") ]]; then
  trunk fmt
  trunk check
fi
