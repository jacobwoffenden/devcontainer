#!/usr/bin/env bash

set -e
set -u
set -o pipefail

####################
# Variables
####################
CONTAINER_IMAGE_NAME="jacobwoffenden-devcontainer"
CONTAINER_NAME="jacobwoffenden-devcontainer"
CONTAINER_USERNAME="jacobwoffenden"

SCRIPT_MODE="${1}"
####################
# Functions
####################
cleanUntaggedContainers() {
  danglingContainerCount=$( docker images --quiet --filter "dangling=true" | wc -l | xargs )
  if [[ "${danglingContainerCount}" -gt 0 ]]; then
    echo "---> Removing untagged containers [ ${danglingContainerCount} ]"
    docker rmi -f $( docker images --quiet --filter "dangling=true"  ) &> /dev/null
  fi
}

removeContainer() {
  getContainerId=$( docker ps --quiet --filter "name=${CONTAINER_NAME}" )
  if [[ ! -z "${getContainerId}" ]]; then
    echo "---> Removing container [ ${CONTAINER_NAME} ]"
    docker rm --force "${CONTAINER_NAME}" &> /dev/null
  fi
}

buildContainer() {
  echo "---> Building container [ ${CONTAINER_IMAGE_NAME} ]"
  dockerBuild=$( docker build \
    --quiet \
    --build-arg CONTAINER_USERNAME="${CONTAINER_USERNAME}" \
    --file devcontainer/Containerfile \
    --tag "${CONTAINER_IMAGE_NAME}" \
    . )
  cleanUntaggedContainers
}

launchContainer() {
  echo "---> Launching container [ ${CONTAINER_NAME} ]"
  dockerLaunch=$( docker run \
    --init \
    --privileged \
    --cap-add=SYS_PTRACE \
    --security-opt \
      seccomp=unconfined \
    --interactive \
    --tty \
    --detach \
    --name ${CONTAINER_NAME} \
    --volume ${CONTAINER_NAME}-workspace:/home/${CONTAINER_USERNAME}/workspace \
    --volume ${CONTAINER_NAME}-commandhistory:/home/${CONTAINER_USERNAME}/.commandhistory \
    --volume ${CONTAINER_NAME}-dockerconfig:/home/${CONTAINER_USERNAME}/.docker \
    --volume ${CONTAINER_NAME}-docker:/var/lib/docker \
    ${CONTAINER_IMAGE_NAME} )

    echo "---> Closing Visual Studio Code"
    osascript -e 'quit app "Visual Studio Code"'

    echo "---> Opening Visual Studio Code"
    containerHex=$( echo "{\"containerName\":\"${CONTAINER_NAME}\"}" | od -A n -t x1 | tr -d '[ \n\t ]' | xargs )
    code --folder-uri=vscode-remote://attached-container+${containerHex}/home/${CONTAINER_USERNAME}/workspace

}

devcontainerManifest() {
  echo "---> Creating devcontainer manifest"
  mkdir -p "/Users/${USER}/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs"
  cp vscode/${CONTAINER_NAME}.json.tpl "/Users/${USER}/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs/${CONTAINER_NAME}.json"
  sed -i '' "s|CONTAINER_USERNAME|${CONTAINER_USERNAME}|" "/Users/${USER}/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs/${CONTAINER_NAME}.json"
}

####################
# Main
####################
if [[ "${TERM_PROGRAM}" == "vscode" ]]; then
  echo "This script is designed to be run directly from Terminal.app and Not Visual Studio Code"
  exit 1
fi

case ${SCRIPT_MODE} in
  install | update )
    removeContainer
    buildContainer
    devcontainerManifest
    launchContainer
  ;;
  launch )
    removeContainer
    launchContainer
  ;;
  * )
    echo "not supported"
  ;;
esac