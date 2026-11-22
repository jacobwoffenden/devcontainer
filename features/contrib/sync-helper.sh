#!/usr/bin/env bash

FEATURES_DIR="features/src"
HELPER_SCRIPT="features/lib/devcontainer-feature-helper-functions.sh"

for folder in $(find "${FEATURES_DIR}" -mindepth 1 -maxdepth 1 -type d); do
  echo "Processing ${folder}"
  cp --force "${HELPER_SCRIPT}" "${folder}/" || echo "Failed to copy helper script to ${folder}"
done
