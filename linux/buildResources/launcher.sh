#!/usr/bin/env bash

# Setting variables
BASE_DIR=/opt/{PACKAGE_NAME}
APP_DIR=$BASE_DIR
SETTINGS_FILE=$BASE_DIR/app_config.env
export APP_RESOURCES_DIR="$APP_DIR/lib/"

USER_APP_DIR=~/.local/share/{PACKAGE_NAME}
PIDFILE=$USER_APP_DIR/{PACKAGE_NAME}.pid
LOGFILE=$USER_APP_DIR/{PACKAGE_NAME}.log

# set available port environment variable (exported as $ROCKET_PORT )
source $BASE_DIR/find_free_port.sh

# Create USER_APP_DIR if needed
if ! [ -d $USER_APP_DIR ]; then
    mkdir -p $USER_APP_DIR
fi

# Run everything from the app dir
cd $APP_DIR

# Start the server (only when not already running)
if ! [ -f $PIDFILE ]; then
    # Start the server
    $APP_DIR/bin/server.bin >> $LOGFILE &

    # Save PID
    pidof server.bin > $PIDFILE
fi

# Start the client
source $SETTINGS_FILE
$APP_DIR/viewer/electron --no-sandbox $APP_DIR/viewer

# This part happens when the client stops (right?)
# Stop server and remove pidfile
kill `cat $PIDFILE` >> $LOGFILE
rm -f $PIDFILE