#!/usr/bin/env bash

# This is the production launcher installed by .deb to /usr/bin/<full-app-name>

# Setting variables
BASE_DIR=/opt/{PACKAGE_NAME}
APP_DIR=$BASE_DIR
SETTINGS_FILE=$BASE_DIR/app_config.env
export APP_RESOURCES_DIR="$APP_DIR/lib/"

# Run everything from the app dir
cd $APP_DIR

# Start the client, which will start the server
source $SETTINGS_FILE
$APP_DIR/viewer/electron --no-sandbox $APP_DIR/viewer
