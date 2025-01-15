#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# source scripts/aliases.sh
# source scripts/environment.sh

git submodule update --init

# dependencies
if [[ -n $(command -v "apt-get") ]]; then
  commands=(
    "cpufetch"
    "curl"
    "git"
    "gnupg2"
    "jq"
    "yq"
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

# copy if not present in the current directory
items=(
  "modules/config/.editorconfig"
  "modules/config/.github"
  "modules/config/.gitignore"
  "modules/config/.ssh/config"
  "modules/config/.trunk"
  "modules/config/code-of-conduct.md"
  "modules/config/compose-dev.yaml"
  "modules/config/CONTRIBUTING.md"
  "modules/config/PULL_REQUEST_TEMPLATE.md"
  "modules/config/SECURITY_CONTACTS"
  "modules/config/SECURITY.md"
  "modules/toolchain/.devcontainer"
)
for item in "${items[@]}"; do
  cp -n -r "${item}" "${PWD}"
done

# create symlinks in the current directory
ln -s \
  modules/config/.commitlintrc \
  modules/config/.vscode \
  "${PWD}"

# create symlinks in the home directory
ln -s \
  modules/config/.bashrc \
  modules/config/.gitconfig \
  modules/config/.zshrc \
  "${HOME}"

touch CODEOWNERS
mkdir -p config hack scripts tools

# configurations
cd config
ln -s \
  ../modules/config/Brewfile \
  ../modules/config/kind.yaml \
  ../modules/config/psp.yaml \
  ../modules/config/rbac.yaml \
 "${PWD}"
cd -

# hacks
cd hack
cp -n \
  ../modules/toolchain/hack/* \
  "${PWD}"
cd -

# scripts
cd scripts
ln -s \
  ../modules/toolchain/scripts/aliases.sh \
  ../modules/toolchain/scripts/configure.sh \
  ../modules/toolchain/scripts/environment.sh \
  ../modules/toolchain/scripts/install.sh \
 "${PWD}"
cd -

# tools
cd tools
ln -s \
  ../modules/toolchain/tools/kind \
  ../modules/toolchain/tools/minikube \
  "${PWD}"
cd -

# shell
sudo chsh -s "$(command -v zsh)" "${USER}"

# trunk.io
[[ -d .trunk/configs ]] && ln -s .trunk/configs/.* "${PWD}"
if [[ -n $(command -v "trunk") ]]; then
  trunk fmt
  trunk check
else
  curl https://get.trunk.io -fsSL | bash
  trunk fmt
  trunk check
fi
