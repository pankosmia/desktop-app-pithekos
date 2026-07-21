#!/usr/bin/env bash

set -e
set -u

echo

# This file is used by GHA to send a version suffix argument.
# The argument will be appended to the end of APP_VERSION in app_config.env

if [ -n "$1" ]; then
  # Rewrite the APP_VERSION in app_config.env
  configFile="../../app_config.env"

  echo "  Using version suffix \"$1\""
  sed -i '' '/^APP_VERSION/ s/$/'-"$1"'/' "$configFile"
fi