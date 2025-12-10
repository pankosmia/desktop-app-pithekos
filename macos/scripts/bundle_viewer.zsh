#!/usr/bin/env zsh

# This script uses the APP_VERSION environment variable as defined in app_config.env

# Run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./bundle_viewer.zsh
# with the optional arguments of: ./bundle_viewer.zsh -s
# to pre-specify that the server is off.

set -e
set -u

echo

# Do not ask if the server is off if the -s $1 positional argument is provided
askIfOff="${1:-yes}" # -s means "no"
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

if [ ! -f ../../local_server/target/release/local_server ]; then
  echo
  echo "   *****************************************************************************************"
  echo "   * IMPORTANT: Build the local server (without the -d argument), then re-run this script! *"
  echo "   *****************************************************************************************"
  echo
  exit
fi

TEMP_DIR=../temp
if [ -d $TEMP_DIR ]; then
    echo "Deleting previous build..."
    echo
    rm -rf $TEMP_DIR
fi

# The bundle_zip script will ensure the latest is checked out, the clone is installed, and the app_setup script is run
echo
echo "Bundling Zip..."
echo "  - updates the build environment for the Electronite package build,"
echo "  - and creates a zip bundle that parallels the Electronite package."
./bundle_zip.zsh -s

echo
echo
echo "********************************************************************"
echo "\"Getting Electron release\" downloads an approximately 120 MB file."
echo "Please wait patiently for the download process to complete..."
echo "********************************************************************"
echo

../install/makeAllInstallsElectronite.sh
