#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

set -xe

# Pull images
pull_images() {
  awk '/docker-/ {print $2}' $1 | while read -r image; do
    if [ "$(docker image ls $image --quiet | wc -l)" -eq 0 ]; then
      docker pull "$image"
    fi
    #./bin/kind load docker-image "$image" --name="$KIND_CLUSTER_NAME"

    IMG=$(echo $images | rev | cut -d'/' -f1 | rev)
    docker image save "$image" -o "$IMG".tar.gz
  done
}

pull_images ${PWD}/values.yaml
