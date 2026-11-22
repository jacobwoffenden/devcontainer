#!/usr/bin/env bash

# Environment
export DEBIAN_FRONTEND="noninteractive"

# Functions

logger() {
  local type="${1}"
  local message="${2}"
  local timestamp
  timestamp=$(date --rfc-3339=seconds)

  case "${type}" in
  err | error)
    echo "${timestamp} [ERROR] ${message}"
    ;;
  info | information)
    echo "${timestamp} [INFO] ${message}"
    ;;
  warn | warning)
    echo "${timestamp} [WARN] ${message}"
    ;;
  esac
}

get_architecture() {
  uname=$(uname --machine)

  case "${uname}" in
    x86_64)
      export ARCHITECTURE="x86_64"
      export ALT_ARCHITECTURE="amd64"
      ;;
    aarch64)
      export ARCHITECTURE="aarch64"
      export ALT_ARCHITECTURE="arm64"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}
