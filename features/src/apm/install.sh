#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY="microsoft/apm"
APM_VERSION="${APMVERSION:-latest}"
INSTALLATION_DIRECTORY="/usr/local/bin/apm"

# System Architecture
case "$(uname --machine)" in
  x86_64)
    ARCHITECTURE="amd64"
    ;;
  aarch64)
    ARCHITECTURE="arm64"
    ;;
  *)
    echo "Unsupported architecture: $(uname --machine)"
    exit 1
    ;;
esac

# Version
