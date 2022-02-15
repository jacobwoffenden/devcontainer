#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -x

####################
# Variables
####################
DEBIAN_FRONTEND="noninteractive"
USERNAME="${CONTAINER_USERNAME}"
USER_UID="1000"
USER_GID="1000"

VSCODE_DEVCONTAINERS_VERSION="${TOOL_VERSION_VSCODE_DEVCONTAINERS}"

####################
# Functions
####################
initialiseApt() {
  apt update --assume-yes
  apt upgrade --assume-yes
  apt install --assume-yes \
    apt-transport-https \
    bash \
    ca-certificates \
    curl
  
  apt install --assume-yes \
    icu-devtools
}

vscodeCommon() {
  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/common-debian.sh \
    --output /tmp/common-debian.sh
  bash /tmp/common-debian.sh "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "true" "true" "false"
  chsh --shell /bin/zsh "${USERNAME}"
  rm --force /tmp/common-debian.sh

  mkdir --parents /usr/local/etc/vscode-dev-containers
  mv /root/src/first-run-notice.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt
}

vscodeDocker() {
  groupadd --gid 800 docker
  usermod --append --groups docker ${USERNAME}

  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/docker-in-docker-debian.sh \
    --output /tmp/docker-in-docker-debian.sh
  bash /tmp/docker-in-docker-debian.sh "true" "${USERNAME}" "true" "latest"
  rm --force /tmp/docker-in-docker-debian.sh
}

vscodeSsh() {
  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/sshd-debian.sh \
    --output /tmp/sshd-debian.sh
  bash /tmp/sshd-debian.sh "2222" "${USERNAME}" "false" "skip" "true"
}

configureArtefacts() {
  mv /root/src/zshrc /home/${USERNAME}/.zshrc
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.zshrc
}

configureFilesystem() {
  mkdir --parents /home/${USERNAME}/workspace
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/workspace

  mkdir --parents /home/${USERNAME}/.commandhistory
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.commandhistory

  mkdir --parents /home/${USERNAME}/.docker
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.docker
}

cleanApt() {
  apt clean autoclean --assume-yes
  apt autoremove --assume-yes
  rm --force --recursive /var/lib/{apt,dpkg,cache,log}
}

####################
# Main
####################
initialiseApt
vscodeCommon
vscodeDocker
vscodeSsh
configureArtefacts
configureFilesystem

####################
# Post
####################
cleanApt