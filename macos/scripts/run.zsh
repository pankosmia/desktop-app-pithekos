#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./run.zsh
# with the optional argument of: `./run.zsh -s` to pre-specify that the server is off.

set -e
set -u

echo

# Do not ask if the server is off if the -s argument is provided
while [[ "$#" -gt 0 ]]
  do case $1 in
      -s) askIfOff="$1" # -s means "no"
      ;;
  esac
  shift
done

# Assign default value if -s is not present
if [ -z ${askIfOff+x} ]; then # askIfOff is unset
  askIfOff=-yes
fi

if [ ! -f ../../local_server/target/release/local_server ]; then
  echo
  echo "      Exiting..."
  echo
  echo "      The local server does not exist. Run \`./build_server.zsh\`, then re-run this script."
  echo
  exit
fi

# Do not ask if the server is off if the -s argument is provided
if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Is the server off? [Y/n]: "
    case $choice in
      "y" | "Y" | "" ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting..."
        echo
        echo "If the server is on, turn it off (e.g., Ctrl-C in terminal window or exit app), then re-run this script."
        echo
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
        echo
        ;;
    esac
  done
fi

if [ ! -f ../../buildSpec.json ] || [ ! -f ../../globalBuildResources/i18nPatch.json ] || [ ! -f ../../globalBuildResources/product.json ] || [ ! -f ../buildResources/setup/app_setup.json ]; then
  ./app_setup.zsh
  echo
  echo "  +-----------------------------------------------------------------------------+"
  echo "  | Config files were rebuilt by \`./app_setup.zsh\` as one or more were missing. |"
  echo "  +-----------------------------------------------------------------------------+"
  echo
fi

# set available port environment variable (exported as $ROCKET_PORT )
source ../buildResources/find_free_port.sh
echo "Serving on port $ROCKET_PORT..."
echo

if [ -d ../build ]; then
  echo "Removing last build environment..."
  echo
  rm -rf ../build
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment..."
  node ./build.js
fi

cd ../build

echo
echo "Running with local server in release mode... When ready to stop this server, press Ctrl-C."
echo "       If Ctrl-Z (suspend) is used by accident, then run \`killall -9 \"server.bin\"\` or Force Quit from the Activity Monitor,"
echo "       or to resume run \`fg\` for the last suspended process, otherwise \`fg \"./run.zsh\"\`."
echo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export APP_RESOURCES_DIR="$SCRIPT_DIR/lib/"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
$SCRIPT_DIR/bin/server.bin
