#!/usr/bin/env bash

docker run -it --rm \
  --volume "${PWD}":/workspace \
  --name debug-feature \
  mcr.microsoft.com/devcontainers/base:ubuntu26.04
