#!/bin/sh

# This script uses the APP_VERSION and APP_NAME environment variables as defined in app_config.env, as well as $filename
source ../../app_config.env $filename

EMSG="environment variable is not set in makeInstallFromBuild.sh."

# Confirm both APP_VERSION and APP_NAME environment variables are set
if [ \( -z "$APP_VERSION" \) -o \( -z "$APP_NAME" \) ]; then

    if [ -z "$APP_VERSION" ]; then
      echo "Error: APP_VERSION $EMSG"
    fi

    if [ -z "$APP_NAME" ]; then
      echo "Error: APP_NAME $EMSG"
    fi

    exit 1
fi

# Use lower case app name in filename -- zsh: ${APP_NAME:l}  -- bsh: ${APP_NAME,,} -- sh: $(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
FILE_APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
# Replace spaces with a dash (-) in filename
FILE_APP_NAME=${FILE_APP_NAME// /-}
# Set FILE_APP_NAME environment variable
export FILE_APP_NAME="$FILE_APP_NAME"

# Check if filename and destination are provided as an argument
if [ -z "$3" ]; then
  echo "Usage: $0 <filename> <destination-folder> <arch>"
  exit 1
fi

# get arguments
filename="$1"
destination="$2/$3"
arch="$3"

echo "Processing '$filename'"

./makeInstall.sh $arch

rm -rf "$destination"
mkdir -p "$destination"
cp ../../releases/macos/${FILE_APP_NAME}-macos-installer-${arch}-*.pkg "$destination"
echo "Files at $destination"
ls -als "$destination/"
