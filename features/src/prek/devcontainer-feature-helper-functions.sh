#!/usr/bin/env bash

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
