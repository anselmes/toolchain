#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/aliases.sh
# source scripts/environment.sh

# dependencies
if [[ -n $(command -v "apt-get") ]]; then
  commands=(
    "curl"
    "git"
    "gnupg2"
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
    user="devcontainer"
  else
    user="$(whoami)"
  fi

  for g in "${groups[@]}"; do
    sudo usermod -aG "${g}" "${user}"
  done

  id "${user}"
fi

# environment
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  curl -fsSLo /tmp/ohmyzsh-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  bash /tmp/ohmyzsh-install.sh --unattended || true
  rm -f /tmp/ohmyzsh-install.sh
fi

items=(
  "modules/dotfiles/.devcontainer"
  "modules/dotfiles/.editorconfig"
  "modules/dotfiles/.gitignore"
  "modules/dotfiles/.ssh"
  "modules/dotfiles/.trunk"
  "modules/dotfiles/compose-dev.yaml"
)
for item in "${items[@]}"; do
  # copy if not present in the root directory
  ls -l $(basename "${item}") >/dev/null 2>&1 || cp -r "${item}" .
done

ln -sf \
  modules/dotfiles/.bashrc \
  modules/dotfiles/.zshrc \
  modules/dotfiles/.commitlintrc \
  modules/dotfiles/.idea \
  modules/dotfiles/.vscode \
  .

if [[ -d modules/tooling ]]; then
  mkdir -p config hack scripts tools

  cp -f modules/tooling/.gitignore .
  cp -f modules/tooling/.devcontainer/devcontainer.json .devcontainer/devcontainer.json

  cd config
  ln -sf ../modules/tooling/config/* .
  cd -

  cd hack
  ln -sf ../modules/tooling/hack/* .
  cd -

  cd scripts
  ln -sf ../modules/tooling/scripts/* .
  cd -

  cd tools
  ln -sf ../modules/tooling/tools/* .
  cd -
fi

# shell
sudo chsh -s "$(command -v zsh)" "${USER}"

# trunk.io
ln -sf .trunk/configs/.* .
if [[ -n $(command -v "trunk") ]]; then
  trunk fmt
  trunk check
fi
