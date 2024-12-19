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
  "modules/config/.devcontainer"
  "modules/config/.editorconfig"
  "modules/config/.gitignore"
  "modules/config/.ssh"
  "modules/config/.trunk"
  "modules/config/compose-dev.yaml"
)
for item in "${items[@]}"; do
  # copy if not present in the root directory
  ls -l $(basename "${item}") >/dev/null 2>&1 || cp -r "${item}" .
done

ln -sf \
  modules/config/.bashrc \
  modules/config/.zshrc \
  modules/config/.commitlintrc \
  modules/config/.idea \
  modules/config/.vscode \
  .

if [[ -d modules/toolchain ]]; then
  mkdir -p config hack scripts tools

  cp -f modules/toolchain/.gitignore .
  ls -l .devcontainer/devcontainer.json >/dev/null 2>&1 ||
    cp -f modules/toolchain/.devcontainer/devcontainer.json .devcontainer/devcontainer.json

  cd config
  ln -sf ../modules/toolchain/config/* .
  cd -

  cd hack
  ln -sf ../modules/toolchain/hack/* .
  cd -

  cd scripts
  ln -sf ../modules/toolchain/scripts/* .
  cd -

  cd tools
  ln -sf ../modules/toolchain/tools/* .
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
