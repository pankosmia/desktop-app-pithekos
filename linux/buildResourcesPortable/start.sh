#!/usr/bin/env bash

# Setting variables
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/%%APP_NAME%%"
APP_DIR="$BASE_DIR"
SETTINGS_FILE="$BASE_DIR/app_config.env"
# export APP_RESOURCES_DIR="$APP_DIR/lib/"

# Run everything from the app dir
cd "$APP_DIR" || exit 1

# Load configuration
source "$SETTINGS_FILE"

echo "Launching %%APP_NAME%% in another window..."

# Start Electron as a background process.
setsid nohup "$APP_DIR/viewer/electron" \
  --no-sandbox "$APP_DIR/viewer" \
  </dev/null >"$APP_DIR/electron.log" 2>&1 &

# Keep this window open long enough for the echo to be read.
sleep 4

exit 0
