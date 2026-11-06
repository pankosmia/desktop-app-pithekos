#!/usr/bin/env bash

# This is an alternative production launcher for developer use. It shows Electron stdio in the terminal.

# Location: '<App Name>.app/devAppLauncherElectron.sh'

echo
echo "=================================================================="
echo "Starting up with Electron stdin, stdout and stderr in the console:"
echo

# Contents/ dir = the directory this script is in
BASE_DIR="$(cd "$(dirname "$0")/Contents" >/dev/null 2>&1 && pwd)"
cd "$BASE_DIR" || { echo "Error: cannot cd to $BASE_DIR"; exit 1; }
echo "Running everything from: $BASE_DIR"
echo

export APP_RESOURCES_DIR=./lib/
echo "APP_RESOURCES_DIR: $APP_RESOURCES_DIR"
echo

START_CMD=(./electron/Electron/Contents/MacOS/Electron ./electron)
printf 'Starting with: %s\n' "${START_CMD[*]}"
echo

# exec: Electron takes over this terminal's stdin/stdout/stderr and receives Ctrl+C directly
exec "${START_CMD[@]}"
