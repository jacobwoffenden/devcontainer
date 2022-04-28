#!/usr/bin/env bash

set -e
set -u
set -o pipefail

####################
# Variables
####################
BUILD_DEBUG="${BUILD_DEBUG:-0}"
SCRIPT_MODE="${1}"

CONTAINER_IMAGE_NAME="devcontainer"
CONTAINER_NAME="devcontainer"
CONTAINER_USERNAME="devcontainer"

####################
# Functions
####################
clean_untagged_containers() {
  danglingContainerCount=$( docker images --quiet --filter "dangling=true" | wc -l | xargs )
  if [[ "${danglingContainerCount}" -gt 0 ]]; then
    echo "---> Removing untagged containers [ ${danglingContainerCount} ]"
    docker rmi -f $( docker images --quiet --filter "dangling=true"  ) &> /dev/null
  fi
}

remove_container() {
  getContainerId=$( docker ps --all --quiet --filter "name=${CONTAINER_NAME}" )
  if [[ ! -z "${getContainerId}" ]]; then
    echo "---> Removing container [ ${CONTAINER_NAME} ]"
    docker rm --force "${CONTAINER_NAME}" &> /dev/null
  fi
}

build_container() {
  echo "---> Building container [ ${CONTAINER_IMAGE_NAME} ]"

  if [[ "${BUILD_DEBUG}" -eq 1 ]]; then
    buildMode=""
  else
    buildMode="--quiet"
  fi

  dockerBuild=$( docker build ${buildMode} \
    --build-arg CONTAINER_USERNAME="${CONTAINER_USERNAME}" \
    --file devcontainer/Containerfile \
    --tag "${CONTAINER_IMAGE_NAME}" \
    . 
  )

  clean_untagged_containers
}

launch_container() {
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
    --volume ${CONTAINER_NAME}-github:/home/${CONTAINER_USERNAME}/.config/gh \
    --volume ${CONTAINER_NAME}-aws:/home/${CONTAINER_USERNAME}/.aws \
    --volume ${CONTAINER_NAME}-awsvault:/home/${CONTAINER_USERNAME}/.awsvault \
    --volume ${CONTAINER_NAME}-kube:/home/${CONTAINER_USERNAME}/.kube \
    --volume ${CONTAINER_NAME}-gcloud:/home/${CONTAINER_USERNAME}/.config/gcloud \
    --volume ${CONTAINER_NAME}-configstore:/home/${CONTAINER_USERNAME}/.config/configstore \
    --volume ${CONTAINER_NAME}-docker:/var/lib/docker \
    ${CONTAINER_IMAGE_NAME} 
  )

  sleep 2

  install_devcontainer_manifest

  echo "---> Opening Visual Studio Code"
  containerHex=$( echo "{\"containerName\":\"${CONTAINER_NAME}\"}" | od -A n -t x1 | tr -d '[ \n\t ]' | xargs )
  code --folder-uri=vscode-remote://attached-container+${containerHex}/home/${CONTAINER_USERNAME}/workspace

}

install_devcontainer_manifest() {
  echo "---> Creating devcontainer manifest"
  mkdir -p "/Users/${USER}/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs"
  cp vscode/${CONTAINER_NAME}.json "/Users/${USER}/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs/${CONTAINER_NAME}.json"
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
    remove_container
    build_container
    launch_container
  ;;
  launch | restart )
    remove_container
    launch_container
  ;;
  * )
    echo "not supported"
  ;;
esac