#!/bin/sh

# This is the .app launcher
# It becomes '<App Name>.app/Contents/MacOS/start-<app-name>.sh',
# designated in the CFBundleExecutable key of 'Info.plist'.

echo "========================"
echo "Starting up:"

# Contents/ dir = parent of the directory this script is in
BASE_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
cd "$BASE_DIR" || { echo "Error: cannot cd to $BASE_DIR"; exit 1; }

echo "Running everything from: $BASE_DIR"

# start electron
export APP_RESOURCES_DIR=./lib/
./electron/Electron/Contents/MacOS/Electron ./electron