#!/usr/bin/env bash

####################
# Variables
####################
CONTAINER_BASE_IMAGE="public.ecr.aws/ubuntu/ubuntu:20.04_stable"
CONTAINER_IMAGE_NAME="ghcr.io/jacobwoffenden/devcontainer"
CONTAINER_NAME="jacobwoffenden-devcontainer"
CONTAINER_USERNAME="jacobwoffenden"

TOOL_VERSION_VSCODE_DEVCONTAINERS="v0.222.0" # https://github.com/microsoft/vscode-dev-containers/releases

SCRIPT_MODE="${1}"
####################
# Functions
####################
buildContainer() {
  echo "---> Building Container [ ${CONTAINER_IMAGE_NAME} ]"
  docker build \
    --build-arg CONTAINER_BASE_IMAGE="${CONTAINER_BASE_IMAGE}" \
    --build-arg CONTAINER_USERNAME="${CONTAINER_USERNAME}" \
    --build-arg TOOL_VERSION_VSCODE_DEVCONTAINERS="${TOOL_VERSION_VSCODE_DEVCONTAINERS}" \
    --file devcontainer/Containerfile \
    --tag "${CONTAINER_IMAGE_NAME}" \
    .
  cleanUntaggedContainers
}

cleanUntaggedContainers() {
  danglingContainerCount=$( docker images --quiet --filter "dangling=true" | wc -l | xargs )
  if [[ "${danglingContainerCount}" -gt 0 ]]; then
    echo "---> Cleaning Dangling Container Images [ ${danglingContainerCount} ]"
    docker rmi -f $( docker images --quiet --filter "dangling=true"  )
  fi
}

deleteContainer() {
  getContainerId=$( docker ps --quiet --filter "name=${CONTAINER_NAME}" )
  if [[ ! -z "${getContainerId}" ]]; then
    echo "---> Deleting Container [ ${CONTAINER_NAME} ]"
    docker rm --force "${CONTAINER_NAME}"
  fi
}

launchContainer() {
  echo "---> Launching Container"
  docker run \
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
    ${CONTAINER_IMAGE_NAME}

    containerHex=$( echo "{\"containerName\":\"${CONTAINER_NAME}\"}" | od -A n -t x1 | tr -d '[ \n\t ]' | xargs )
    code --folder-uri=vscode-remote://attached-container+${containerHex}/home/${CONTAINER_USERNAME}/workspace
}

####################
# Main
####################
case ${SCRIPT_MODE} in
  install )
    deleteContainer
    buildContainer
    # launchContainer
  ;;
  * )
    echo "not supported"
  ;;
esac