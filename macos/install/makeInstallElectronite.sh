#!/bin/sh

# MacOS Installation Package Builder Script
#
# Synopsis:
#   Creates a macOS installation package (.pkg) for the application
#   based on provided architecture (arm64 or x64) and APP_VERSION.
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
#   - Architecture parameter must be provided when running the script (arm64 or x64)
#   - XCode command line tools must be installed
#   - brew package manager with shc installed (`brew install shc`)
#
# Parameters:
#   $1 : Architecture type (Required)
#        Accepted values: arm64, x64
#   $2 : -d indicates a development run (for building viewer only)
#   -f indicates full install including Electronite copy/download setup
#   -p indicates Portable App zip build
#
# Returns:
#   0 : Success
#   1 : Failure (Invalid/missing parameters or execution error)
#
# Output:
#   Creates installer package at: ../releases/macos/<app-name>_installer_<arch>_<version>.pkg

EMSG="environment variable is not set in makeInstallElectronite.sh."

# Check if APP_NAME environment variable is set
if [ -z "$APP_NAME" ]; then
    echo "Error: APP_NAME $EMSG"
    exit 1
fi

# Check if APP_VERSION environment variable is set
if [ -z "$APP_VERSION" ]; then
    echo "Error: APP_VERSION $EMSG"
    exit 1
fi

# Check if APP_SHORT_NAME environment variable is set
if [ -z "$APP_SHORT_NAME" ]; then
    echo "Error: APP_SHORT_NAME $EMSG"
    exit 1
fi

# Check if FILE_APP_NAME environment variable is set
if [ -z "$FILE_APP_NAME" ]; then
    echo "Error: FILE_APP_NAME $EMSG"
    exit 1
fi

# get arguments
arch="$1"
devRun="${2:-no}" # This is a development viewer run if $1 is -d
fullInstall=false
portable=false

for arg in "$@"; do
    case "$arg" in
        -f) fullInstall=true ;;
        -p) portable=true ;;
    esac
done

PKG_BASE_NAME="${FILE_APP_NAME}-${APP_VERSION}-macos-${arch}"
PKG_NAME="${PKG_BASE_NAME}.pkg"
PKG_ZIP_NAME="${PKG_BASE_NAME}.zip"

# Needed for local bundles. Not required in GHA but does no harm.
if [ "$devRun" != "-d" ]; then  
  rm -f "../../releases/macos/${PKG_NAME}"
  rm -f "../../releases/macos/${PKG_ZIP_NAME}"
fi

cd ../build || exit 1

########################################
# build folder structure for package

# Turn on command echo
# set -x

if [ "$devRun" = "-d" ]; then
    pkgDir="viewer"
else
    pkgDir="temp"
fi

APP_BASE_DIR="../$pkgDir/project/payload/${APP_NAME}.app" # temp app foldername without spaces, will rename to actual name later

# Needed for local bundles. Not required in GHA but also doesn't hurt anything.
if [ "$fullInstall" = true ] || [ "$devRun" != "-d" ]; then
    rm -rf "../$pkgDir/project"
fi

mkdir -p "${APP_BASE_DIR}/Contents/MacOS"

# Rocket config
cp "../../Rocket.toml" "${APP_BASE_DIR}/Rocket.toml"

# alternative production launcher for developer use
STDIO_LAUNCHER="${APP_BASE_DIR}/devAppLauncherElectron.sh"
cp "../buildResources/devAppLauncherElectron.sh" "$STDIO_LAUNCHER"
chmod +x "$STDIO_LAUNCHER"

# electron startup
LAUNCHER_NAME="start-${FILE_APP_NAME}.sh"
cp "../buildResources/appLauncherElectron.sh" "${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}"
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}"

#remove backup
rm "${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}.bak"

ELECTRON_DEST="${APP_BASE_DIR}/Contents/electron"
NODE_MODULES_SRC="../../node_modules"
NODE_MODULES_DEST="${ELECTRON_DEST}/node_modules"

# copy app-specific electron files
cp -R "../../buildResources/electron/." "$ELECTRON_DEST/"
echo "Successfully copied app-specific electron files"

if [ ! -d "$ELECTRON_DEST" ]; then
    echo "Error: Electron destination path not found for app-specific electron files: $ELECTRON_DEST"
    exit 1
fi

cp "../../globalBuildResources/favicon"*.png "$ELECTRON_DEST"
echo "Copied favicon files"

# Copy required node_modules and dependencies -- all OSes
ALL_OS_MODULES="
puppeteer-core
@puppeteer/browsers
chromium-bidi
debug
devtools-protocol
ms
typed-query-selector
webdriver-bidi-protocol
ws
semver
proxy-agent
lru-cache
agent-base
proxy-from-env
progress
mitt
"

for mod in $ALL_OS_MODULES; do
    mkdir -p "${NODE_MODULES_DEST}/${mod}"
    cp -R "${NODE_MODULES_SRC}/${mod}/." "${NODE_MODULES_DEST}/${mod}/"
done

echo "Successfully copied node_modules dependencies"

# Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${ELECTRON_DEST}/electronStartup.js"  # Replace all occurrences of ${APP_NAME}
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${ELECTRON_DEST}/package.json"  # Replace all occurrences of ${APP_NAME}
sed -i.bak "s/\${APP_VERSION}/$APP_VERSION/g" "${ELECTRON_DEST}/package.json"  # Replace all occurrences of ${APP_VERSION}

# now copy architecture specific electron files
if [ "$fullInstall" = true ]; then
    cp -R "../$pkgDir/electron.$arch/"* "$ELECTRON_DEST"
else
    echo "Skipping architecture-specific electron file copy (not needed)."
fi

# Check if Electron executable owner is current user
ELECTRON_OWNER=$(stat -f %u "${APP_BASE_DIR}/Contents/electron/Electron.app/Contents/MacOS/Electron")
CURRENT_USER=$(id -u)
if [ "$ELECTRON_OWNER" != "$CURRENT_USER" ]; then
    echo "Error: Electron executable owner is not current user. Please run: sudo chown -R $(id -u):$(id -g) ../buildResources/electron.$arch/*"
    exit 1
fi

# rename Electron.app folder
mv "${APP_BASE_DIR}/Contents/electron/Electron.app" "${APP_BASE_DIR}/Contents/electron/Electron"

chmod 755 "${APP_BASE_DIR}/Contents/electron/Electron/Contents/MacOS/Electron"

# update Info.plist file in Electron folder - insert app name
echo "Updating Electron Info.plist file"
PLIST_FILE_ELECTRON="${APP_BASE_DIR}/Contents/electron/Electron/Contents/Info.plist"
sed -i.bak "/CFBundleDisplayName/{n;s/Electron/$APP_NAME/g;}" "$PLIST_FILE_ELECTRON"
sed -i.bak "/CFBundleName/{n;s/Electron/$APP_NAME/g;}" "$PLIST_FILE_ELECTRON"
# show updated file contents
cat "$PLIST_FILE_ELECTRON"
echo "Done Updating Electron Info.plist file"

if [ "$devRun" != "-d" ]; then
  mkdir -p "${APP_BASE_DIR}/Contents/Resources"
  cp "../../globalBuildResources/icon.icns" "${APP_BASE_DIR}/Contents/Resources/icon.icns"

  # copy Info.plist
  cp "../buildResources/Info.plist" "${APP_BASE_DIR}/Contents/"
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

  cp -R "./bin" "${APP_BASE_DIR}/Contents/"
  echo "copied bin to $APP_BASE_DIR/Contents/"
  chmod 755 "${APP_BASE_DIR}/Contents/bin/server.bin"
  chmod 755 "${APP_BASE_DIR}/Contents/MacOS/${LAUNCHER_NAME}"

  cp -R "./lib" "${APP_BASE_DIR}/Contents/"
  echo "copied lib to $APP_BASE_DIR/Contents/"

  SCRIPTS_DIR="../$pkgDir/project/scripts"
  mkdir -p "$SCRIPTS_DIR"
  PREINST_FILE="../$pkgDir/project/scripts/preinstall"
  cp "../buildResources/preinstall" "$PREINST_FILE"
  echo "copied preinstall to $SCRIPTS_DIR"
  sed -i.bak "s/{APP_SHORT_NAME}/$APP_SHORT_NAME/g" "$PREINST_FILE"
  echo "Replaced {APP_SHORT_NAME} with \"$APP_SHORT_NAME\" in $PREINST_FILE."
  chmod +x "$PREINST_FILE"
  POSTINST_FILE="../$pkgDir/project/scripts/postinstall"
  cp "../build/post_install_script.sh" "$POSTINST_FILE"
  echo "copied post_install_script.sh to $SCRIPTS_DIR"
  echo "Variables in post_install_script.sh were already replaced by: node build.js"
  chmod +x "$POSTINST_FILE"
fi

# set execute permission on all folders
find "${APP_BASE_DIR}/" -type d -exec chmod u+x,g+x,o+x {} +

# rename to final app name
mv "${APP_BASE_DIR}" "$(dirname "${APP_BASE_DIR}")/${APP_NAME}.app"

if [ "$devRun" != "-d" ]; then
  # maintain a one-off identifier for simpler upgrades of early test releases
  if [ "$FILE_APP_NAME" = "liminal" ]; then
    IDENTIFIER="com.yourdomain.liminal"
  else
    IDENTIFIER="pankosmia.${FILE_APP_NAME}"
  fi

  # build pkg
  cd ..
  pkgbuild \
    --root "./$pkgDir/project/payload" \
    --scripts "./$pkgDir/project/scripts" \
    --identifier "${IDENTIFIER}" \
    --version "$APP_VERSION" \
    --install-location /Applications \
    "./build/${PKG_NAME}"

  # unquarantine.sh
  UNQUARANTINE_SRC="./buildResources/unquarantine.sh"
  UNQUARANTINE_DEST="./build/unquarantine.sh"
  cp "$UNQUARANTINE_SRC" "$UNQUARANTINE_DEST"
  sed -i.bak "s/\%%FILE_APP_NAME%%/$FILE_APP_NAME/g" "$UNQUARANTINE_DEST"
  sed -i.bak "s/\%%APP_VERSION%%/$APP_VERSION/g" "$UNQUARANTINE_DEST"
  sed -i.bak "s/\%%ARCH%%/$arch/g" "$UNQUARANTINE_DEST"
  chmod +x "$UNQUARANTINE_DEST"

  # README.txt
  # README_SRC="./buildResources/README.txt"  # build.js handles this
  README_DEST="./build/README.txt"
  # cp "$README_SRC" "$README_DEST"   # build.js handles this
  # sed -i.bak "s/\%%APP_NAME%%/$APP_NAME/g" "$README_DEST"  # build.js handles this
  # sed -i.bak "s/\%%FILE_APP_NAME%%/$FILE_APP_NAME/g" "$README_DEST"  # build.js handles this
  # sed -i.bak "s/\%%APP_VERSION%%/$APP_VERSION/g" "$README_DEST"  # build.js handles this
  sed -i.bak "s/\%%ARCH%%/$arch/g" "$README_DEST"


  # copy to releases folder
  # cp "./build/${PKG_NAME}" "../releases/macos/"
  PKGZIP_RELEASE="../releases/macos/${PKG_ZIP_NAME}"
  zip -X -j "${PKGZIP_RELEASE}" "./build/${PKG_NAME}" "$README_DEST" "$UNQUARANTINE_DEST"

  # ---------------------------------------------------------------------------
  # Portable app packaging (.zip) -- additive; runs only when -p is set and
  # this is not a "dev run".
  #
  # The .pkg has already been built and copied to releases above, so none of
  # the portable replacements below can affect it. The finished .app is copied
  # to a separate portable stage, and ALL portable-specific edits are performed
  # on that staged copy only -- never on the payload the .pkg consumed.
  # ---------------------------------------------------------------------------
  if [ "$portable" = true ]; then
    echo "Building portable ZIP..."

    ARCH="$arch"

    # At this point the CWD is the OS dir (we did `cd ..` before pkgbuild),
    # so the built payload lives under ./$pkgDir/project/payload.
    PAYLOAD_DIR="./$pkgDir/project/payload"
    BUILT_APP="${PAYLOAD_DIR}/${APP_NAME}.app"

    HELPERS_SOURCE="./buildResourcesPortable"

    OUTPUT_PATH="../releases/macos"
    mkdir -p "$OUTPUT_PATH"

    # Stage the portable app (its top-level entry is the .app bundle itself).
    PORTABLE_STAGE="./$pkgDir/project/portable-package"
    PORTABLE_APP_STAGE="${PORTABLE_STAGE}/${APP_NAME}.app"
    PORTABLE_ZIP_PATH="${OUTPUT_PATH}/${PKG_BASE_NAME}-portable.zip"

    if [ ! -d "$BUILT_APP" ]; then
        echo "Error: Built .app not found for portable packaging: $BUILT_APP"
        exit 1
    fi

    rm -rf "$PORTABLE_STAGE"
    mkdir -p "$PORTABLE_STAGE"

    # Copy the finished .app bundle into the portable stage (copy only; the
    # .pkg payload is left untouched).
    cp -R "$BUILT_APP" "$PORTABLE_APP_STAGE"

    # --- user_settings.json (staged copy only) ---
    # Portable app uses a virtual path for repo_dir, two levels up because the
    # working dirs live beside the .app, outside the bundle.
    USER_SETTINGS="${PORTABLE_APP_STAGE}/Contents/lib/templates/user_settings.json"
    if [ ! -f "$USER_SETTINGS" ]; then
        echo "Error: Portable user_settings.json not found: $USER_SETTINGS"
        exit 1
    fi
    sed -i.bak 's#"repo_dir": "%%HOMEDIR%%/pankosmia_repos",#"repo_dir": "../../pankosmia_repos",#' "$USER_SETTINGS"
    rm -f "${USER_SETTINGS}.bak"

    # --- README.txt helper at the ZIP root ---
    README_SOURCE="${HELPERS_SOURCE}/README.txt"
    README_DESTINATION="${PORTABLE_STAGE}/README.txt"
    cp "$README_SOURCE" "$README_DESTINATION"
    # Replace placeholders only in the staged ZIP copy.
    sed -i.bak "s/%%APP_NAME%%/$APP_NAME/g" "$README_DESTINATION"
    sed -i.bak "s/%%APP_SHORT_NAME%%/$APP_SHORT_NAME/g" "$README_DESTINATION"
    sed -i.bak "s/%%ARCH%%/$ARCH/g" "$README_DESTINATION"
    rm -f "${README_DESTINATION}.bak"

    # --- unquarantine.sh helper at the ZIP root ---
    UNQUARANTINE_SOURCE="${HELPERS_SOURCE}/unquarantine.sh"
    UNQUARANTINE_DESTINATION="${PORTABLE_STAGE}/unquarantine.sh"
    if [ ! -f "$UNQUARANTINE_SOURCE" ]; then
        echo "Error: Portable helper file not found: $UNQUARANTINE_SOURCE"
        exit 1
    fi
    cp "$UNQUARANTINE_SOURCE" "$UNQUARANTINE_DESTINATION"
    # Replace placeholders only in the staged ZIP copy.
    sed -i.bak "s/%%APP_NAME%%/$APP_NAME/g" "$UNQUARANTINE_DESTINATION"
    sed -i.bak "s/%%FILE_APP_NAME%%/$FILE_APP_NAME/g" "$UNQUARANTINE_DESTINATION"
    rm -f "${UNQUARANTINE_DESTINATION}.bak"
    
    SERVER_FILE="${PORTABLE_APP_STAGE}/Contents/electron/core/server.js"
    STARTUP_FILE="${PORTABLE_APP_STAGE}/Contents/electron/electronStartup.js"

    # --- server.js (staged copy only) ---
    # spawn(SERVER_EXECUTABLE_PATH, []  ->  spawn(SERVER_EXECUTABLE_PATH, ['../../pankosmia/<short>']
    SERVER_FIND="spawn(SERVER_EXECUTABLE_PATH, ["
    SERVER_REPLACE="spawn(SERVER_EXECUTABLE_PATH, ['../../pankosmia/$APP_SHORT_NAME'"
    if [ ! -f "$SERVER_FILE" ]; then
        echo "Error: server.js not found: $SERVER_FILE"
        exit 1
    fi
    if grep -qF -- "$SERVER_REPLACE" "$SERVER_FILE"; then
        echo "$SERVER_FILE was not updated by this run; replacement already present."
        exit 1
    fi
    if ! grep -qF -- "$SERVER_FIND" "$SERVER_FILE"; then
        echo "Expected original text was not found in $SERVER_FILE ; no change made."
        exit 1
    fi
    sed -i.bak "s#spawn(SERVER_EXECUTABLE_PATH, \[#spawn(SERVER_EXECUTABLE_PATH, ['../../pankosmia/$APP_SHORT_NAME'#" "$SERVER_FILE"
    rm -f "${SERVER_FILE}.bak"

    # --- electronStartup.js (staged copy only) ---
    # Insert the userData setPath line right after app.setName('<APP_NAME>');
    # inside the START_SERVER block. Uses '../../pankosmia/AppData' (two levels
    # up) because the working dirs live beside the .app, outside the bundle.
    STARTUP_ANCHOR="app.setName('$APP_NAME');"
    STARTUP_INSERT="  app.setPath('userData', path.resolve(process.cwd(), '../../pankosmia/AppData', '$APP_SHORT_NAME'));"
    if [ ! -f "$STARTUP_FILE" ]; then
        echo "Error: electronStartup.js not found: $STARTUP_FILE"
        exit 1
    fi
    if grep -qF -- "$STARTUP_INSERT" "$STARTUP_FILE"; then
        echo "$STARTUP_FILE was not updated by this run; setPath line already present."
        exit 1
    fi
    if ! grep -qF -- "$STARTUP_ANCHOR" "$STARTUP_FILE"; then
        echo "Expected anchor text was not found in $STARTUP_FILE ; no change made."
        exit 1
    fi

    NL=$(printf '\n')
    sed -i.bak "s|app.setName('$APP_NAME');|app.setName('$APP_NAME');${NL}${STARTUP_INSERT}|" "$STARTUP_FILE"
    rm -f "$STARTUP_FILE.bak"

    # Create the archive whose top-level entries are the .app bundle and README.
    rm -f "$PORTABLE_ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$PORTABLE_STAGE/${APP_NAME}.app" "$PORTABLE_ZIP_PATH"
    zip -X -j "$PORTABLE_ZIP_PATH" "$README_DESTINATION" "$UNQUARANTINE_DESTINATION"

    if [ ! -f "$PORTABLE_ZIP_PATH" ]; then
        echo "Error: Portable ZIP was not created: $PORTABLE_ZIP_PATH"
        exit 1
    fi

    echo "Portable package created successfully: $PORTABLE_ZIP_PATH"
  fi
fi
