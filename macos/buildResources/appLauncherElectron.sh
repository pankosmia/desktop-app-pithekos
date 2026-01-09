#!/bin/sh

echo "========================"
echo "Starting up:"
echo "Current directory:"
pwd

# find the directory path that contains this script
script_dir="$(dirname "$(realpath "$0")")"
echo "Script directory: $script_dir"

# ============================
# need to find server.bin - this is needed because working directory is not set

# first look for server.bin relative to directory script is in
   if [ -e "$script_dir/../bin/server.bin" ]; then
    BASE="$script_dir/.."

# Otherwise Check for server.bin in ./bin
elif [ -e ./bin/server.bin ]; then
    BASE="."

# Otherwise Check for server.bin in ../bin
elif [ -e ../bin/server.bin ]; then
    BASE=".."

# Otherwise Check for server.bin in ./Contents/bin
elif [ -e ./Contents/bin/server.bin ]; then
    BASE="./Contents"

# finally fall back to default install path
elif [ -e "/Applications/${APP_NAME}.app/Contents/bin/server.bin" ]; then
    BASE="/Applications/${APP_NAME}.app/Contents"

# not found
else
    echo "Error: server.bin not found in ./bin or ../bin"
    exit 1
fi

echo "bin folder found at $BASE"

# set available port environment variable (exported as $ROCKET_PORT )
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/find_free_port.sh"

# start electron
cd "$BASE"
export APP_RESOURCES_DIR=./lib/
./electron/Electron/Contents/MacOS/Electron ./electron