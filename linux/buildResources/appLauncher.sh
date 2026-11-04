#!/usr/bin/env bash

# set available port environment variable (exported as $ROCKET_PORT )
source ./find_free_port.sh

URL="http://localhost:$ROCKET_PORT"
if ! command "firefox --version" >/dev/null 2>&1
then
    firefox "$URL" >/dev/null 2>&1 &
elif [[ -x $BROWSER ]]
then
    "$BROWSER" "$URL" >/dev/null 2>&1 &
elif path=$(which xdg-open || which gnome-open)
then
    "$path" "$URL" >/dev/null 2>&1 &
fi
echo "Launch a web browser and enter http://localhost:$ROCKET_PORT"
echo "(Best viewed with a Graphite-enabled browser such as Firefox.)"
echo " "

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export APP_RESOURCES_DIR="$SCRIPT_DIR/lib/"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
$SCRIPT_DIR/bin/server.bin
