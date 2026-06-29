#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/windows/scripts directory in a terminal with:  ./viewer.zsh
# ./build_viewer.zsh must be run once before ./viewer.zsh will work

export ROCKET_PORT=${1:-19119}
echo "$ROCKET_PORT"

# This gets APP_NAME, needed on the last line.
source ../../app_config.env

echo "========================"
echo "Starting up:"
echo "Starting electronite viewer, accessing the development build environment running at port shown below:"

# Using development server.

# Starting electronite viewer, accessing the development build environment

# This bypasses ../viewer/start-*.sh (which, fyi, originates from ../buildResources/appLauncherElectron.sh)
../viewer/project/payload/${APP_NAME}.app/Contents/electron/Electron/Contents/MacOS/Electron ../viewer/project/payload/${APP_NAME}.app/Contents/electron
