#!/bin/sh

# MacOS Installation Package Builder Script
#
# Synopsis:
#   Creates a macOS installation package (.pkg) for the application
#   based on provided architecture (arm64 or intel64) and APP_VERSION.
#
# Description:
#   This script automates the process of building a macOS installer package by:
#   1. Creating the installation directory structure
#   2. Copying application files and resources
#   3. Setting up proper permissions
#   4. Configuring application metadata (Info.plist)
#   5. Building the final installer package
#
# Requirements:
#   - APP_VERSION environment variable must be set (e.g., export APP_VERSION="0.2.7")
#   - Architecture parameter must be provided when running the script (arm64 or intel64)
#   - XCode command line tools must be installed
#   - brew package manager with shc installed (`brew install shc`)
#
# Parameters:
#   $1 : Architecture type (Required)
#        Accepted values: arm64, intel64
#   $2 : -d indicates a development run (for building viewer only)
#
# Returns:
#   0 : Success
#   1 : Failure (Invalid/missing parameters or execution error)
#
# Output:
#   Creates installer package at: ../releases/macos/<app-name>_installer_<arch>_<version>.pkg

# Check if APP_NAME environment variable is set
if [ -z "$APP_NAME" ]; then
    echo "Error: APP_NAME environment variable is not set."
    exit 1
fi

# Check if APP_VERSION environment variable is set
if [ -z "$APP_VERSION" ]; then
    echo "Error: APP_VERSION environment variable is not set."
    exit 1
fi

# Check if FILE_APP_NAME environment variable is set
if [ -z "$FILE_APP_NAME" ]; then
    echo "Error: FILE_APP_NAME environment variable is not set."
    exit 1
fi

# get arguments
arch="$1"
devRun="${2:-no}" # This is a development viewer run if $1 is -d

# Needed for local bundles. Not required in GHA but does no harm.
if ! [[ $devRun =~ ^(-d) ]]; then
  PKG_NAME="${FILE_APP_NAME}-macos-installer-standalone-${arch}-${APP_VERSION}.pkg"
  rm -f ./build/${PKG_NAME}
  rm -f ../releases/macos/${PKG_NAME}
fi

cd ../build || exit 1

########################################
# build folder structure for package

# Turn on command echo
# set -x

if [[ $devRun =~ ^(-d) ]]; then
        pkgDir=viewer
    else
        pkgDir=temp
    fi

# Needed for local bundles. Not required in GHA but also doesn't hurt anything.
rm -rf ../$pkgDir/project

APP_BASE_DIR="../$pkgDir/project/payload/APP_NAME.app" # temp app foldername without spaces, will rename to actual name later

mkdir -p ${APP_BASE_DIR}/Contents/MacOS

# electron startup
LAUNCHER_NAME="start-${FILE_APP_NAME}.sh"
cp ../buildResources/appLauncherElectron.sh ${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" ${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}
#remove backup
rm "${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}.bak"

# copy shared electron files
cp -R ../../buildResources/electron ${APP_BASE_DIR}/Contents/
cp ../../globalBuildResources/favicon*.png ${APP_BASE_DIR}/Contents/electron
echo "Successfully copied electron files"

# Determine which startup to use -- dev viewer or production
if [[ $devRun =~ ^(-d) ]]; then
  rm ${APP_BASE_DIR}/Contents/electron/electronStartup.js
  cp ${APP_BASE_DIR}/Contents/electron/electronDevStartup.js ${APP_BASE_DIR}/Contents/electron/electronStartup.js
  rm ${APP_BASE_DIR}/Contents/electron/electronDevStartup.js
else
  rm ${APP_BASE_DIR}/Contents/electron/electronDevStartup.js
fi

# Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${APP_BASE_DIR}/Contents/electron/electronStartup.js"  # Replace all occurrences of ${APP_NAME}
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${APP_BASE_DIR}/Contents/electron/package.json"  # Replace all occurrences of ${APP_NAME}
sed -i.bak "s/\${APP_VERSION}/$APP_VERSION/g" "${APP_BASE_DIR}/Contents/electron/package.json"  # Replace all occurrences of ${APP_VERSION}

# now copy architecture specific electron files
cp -R ../$pkgDir/electron.$arch/* ${APP_BASE_DIR}/Contents/electron

# Check if Electron executable owner is current user
ELECTRON_OWNER=$(stat -f %u ${APP_BASE_DIR}/Contents/electron/Electron.app/Contents/MacOS/Electron)
CURRENT_USER=$(id -u)
if [ "$ELECTRON_OWNER" != "$CURRENT_USER" ]; then
    echo "Error: Electron executable owner is not current user. Please run: sudo chown -R $(id -u):$(id -g) ../buildResources/electron.$arch/*"
    exit 1
fi

# rename Electron.app folder 
mv ${APP_BASE_DIR}/Contents/electron/Electron.app ${APP_BASE_DIR}/Contents/electron/Electron

chmod 755 ${APP_BASE_DIR}/Contents/electron/Electron/Contents/MacOS/Electron

# update Info.plist file in Electron folder - insert app name
echo "Updating Electron Info.plist file"
PLIST_FILE_ELECTRON="${APP_BASE_DIR}/Contents/electron/Electron/Contents/Info.plist"
sed -i.bak "/CFBundleDisplayName/{n;s/Electron/$APP_NAME/g;}" "$PLIST_FILE_ELECTRON"
sed -i.bak "/CFBundleName/{n;s/Electron/$APP_NAME/g;}" "$PLIST_FILE_ELECTRON"
# show updated file contents
cat "$PLIST_FILE_ELECTRON"
echo "Done Updating Electron Info.plist file"

if ! [[ $devRun =~ ^(-d) ]]; then
  mkdir -p ${APP_BASE_DIR}/Contents/Resources
  cp ../../globalBuildResources/icon.icns ${APP_BASE_DIR}/Contents/Resources/icon.icns

  # copy Info.plist
  cp ../buildResources/Info.plist ${APP_BASE_DIR}/Contents/
  PLIST_FILE="${APP_BASE_DIR}/Contents/Info.plist"

  # Check if the file exists
  if [ ! -f "$PLIST_FILE" ]; then
      echo "Error: $PLIST_FILE does not exist."
      exit 1
  fi

  # Replace all occurrences of ${APP_NAME}, ${APP_VERSION} and ${FILE_APP_NAME} with the value of their variables
  sed -i.bak "s/\${APP_VERSION}/$APP_VERSION/g" "$PLIST_FILE"
  sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "$PLIST_FILE"
  sed -i.bak "s/\${FILE_APP_NAME}/$FILE_APP_NAME/g" "$PLIST_FILE"

  # Print success message
  echo "Replaced \${APP_VERSION} with \"$APP_VERSION\" in $PLIST_FILE."
  echo "Replaced \${APP_NAME} with \"$APP_NAME\" in $PLIST_FILE."
  echo "Replaced \${FILE_APP_NAME} with \"$FILE_APP_NAME\" in $PLIST_FILE."
  #echo "Backup of original file saved as $PLIST_FILE.bak"
  #remove backup
  rm "$PLIST_FILE.bak"

  echo "New  plist file:"
  cat "$PLIST_FILE"

  cp -R ./bin ${APP_BASE_DIR}/Contents/
  echo "copied bin to $APP_BASE_DIR/Contents/"
  chmod 755 ${APP_BASE_DIR}/Contents/bin/server.bin
  chmod 755 ${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}

  cp -R ./lib ${APP_BASE_DIR}/Contents/
  echo "copied lib to $APP_BASE_DIR/Contents/"

  mkdir -p ../$pkgDir/project/scripts
  cp ../install/post_install_script.sh ../$pkgDir/project/scripts/postinstall
  chmod +x ../$pkgDir/project/scripts/postinstall
fi

# set execute permission on all folders
find ${APP_BASE_DIR}/ -type d -exec chmod u+x,g+x,o+x {} +

# rename to final app name
mv ${APP_BASE_DIR} "$(dirname "${APP_BASE_DIR}")/${APP_NAME}.app"

if ! [[ $devRun =~ ^(-d) ]]; then
  # maintain a one-off identifier for simpler upgrades of early test releases
  if [ "$FILE_APP_NAME" == "liminal" ]; then
    IDENTIFIER="com.yourdomain.liminal"
  else
    IDENTIFIER="pankosmia.${FILE_APP_NAME}"
  fi

  # build pkg
  cd ..
  pkgbuild \
    --root ./$pkgDir/project/payload \
    --scripts ./$pkgDir/project/scripts \
    --identifier ${IDENTIFIER} \
    --version "$APP_VERSION" \
    --install-location /Applications \
    ./build/${PKG_NAME}

  # copy to releases folder
  cp ./build/${PKG_NAME} ../releases/macos/
fi
