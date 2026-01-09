#!/usr/bin/env zsh

# set available port environment variable (exported as $ROCKET_PORT )
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/find_free_port.sh"

clear
URL="http://localhost:$ROCKET_PORT"
if [ -e /Applications/Firefox.app ]
then
    open -a firefox -g "$URL" &
else
    open "$URL" &
fi
echo "Launch a web browser and enter http://localhost:$ROCKET_PORT"
echo "(Best viewed with a Graphite-enabled browser such as Firefox.)"
echo " "
export APP_RESOURCES_DIR=./lib/
./bin/server.bin
