#!/bin/sh

# This script uses the APP_VERSION and APP_NAME environment variables as defined in app_config.env
source ../../app_config.env

# requires shc - do `brew install shc`

# Confirm both APP_VERSION and APP_NAME environment variables are set
EMSG="environment variable is not set in makeInstall.sh."
if [ \( -z "$APP_VERSION" \) -o \( -z "$APP_NAME" \) -o \( -z "$APP_SHORT_NAME" \) ]; then

    if [ -z "$APP_VERSION" ]; then
      echo "Error: APP_VERSION $EMSG"
    fi

    if [ -z "$APP_NAME" ]; then
      echo "Error: APP_NAME $EMSG"
    fi

    if [ -z "$APP_SHORT_NAME" ]; then
      echo "Error: APP_SHORT_NAME $EMSG"
    fi

    exit 1
fi

# Use lower case app name in filename -- zsh: ${APP_NAME:l}  -- bsh: ${APP_NAME,,} -- sh: $(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
FILE_APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
# Replace spaces with a dash (-) in filename
FILE_APP_NAME=${FILE_APP_NAME// /-}
# Set FILE_APP_NAME environment variable
export FILE_APP_NAME="$FILE_APP_NAME"

arch="$1"

# There shouldn't be a need to rm the file from the gh actions runner as it is new every time...
rm -f ../../releases/macos/${FILE_APP_NAME}-macos-installer-${arch}-*.pkg

cd ../build || exit 1

########################################
# build folder structure for package

# Turn on command echo
set -x

# There shouldn't be a need to rm the folder from the gh actions runner as it is new every time
rm -rf ../project

mkdir -p ../project/payload/"$APP_NAME".app/Contents/MacOS

# convert shell script to app
#rm -f ../build/appLauncher.sh.x.c
#shc -f ../build/appLauncher.sh -o ../project/payload/"$APP_NAME".app/Contents/MacOS/start-${FILE_APP_NAME}
#chmod 555 ../project/payload/"$APP_NAME".app/Contents/MacOS/start-${FILE_APP_NAME}

# ../build contains the processed appLauncher.sh and README.txt, which both have variables replaced by `node build.js`
cp ../build/appLauncher.sh ../project/payload/"$APP_NAME".app/Contents/MacOS/start-${FILE_APP_NAME}.sh

mkdir -p ../project/payload/"$APP_NAME".app/Contents/Resources
cp ../build/README.txt ../project/payload/"$APP_NAME".app/Contents/Resources/README.txt
cp ../../globalBuildResources/icon.icns ../project/payload/"$APP_NAME".app/Contents/Resources/icon.icns

# add APP_VERSION, APP_NAME and FILE_APP_NAME to Info.plist. It is correctly in ../buildResources as it is not processed by `node build.js`.
cp ../buildResources/Info.plist ../project/payload/"$APP_NAME".app/Contents/
PLIST_FILE="../project/payload/"$APP_NAME".app/Contents/Info.plist"

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
type $PLIST_FILE

cp -R ./bin ../project/payload/"$APP_NAME".app/Contents/
chmod 755 ../project/payload/"$APP_NAME".app/Contents/bin/server.bin

cp -R ./lib ../project/payload/"$APP_NAME".app/Contents/

mkdir -p ../project/scripts
cp ../buildResources/post_install_script.sh ../project/scripts/postinstall
chmod +x ../project/scripts/postinstall
PREINST_FILE="../project/scripts/preinstall"
cp ../buildResources/preinstall "$PREINST_FILE"
sed -i.bak "s/{APP_SHORT_NAME}/$APP_SHORT_NAME/g" "$PREINST_FILE"
echo "Replaced {APP_SHORT_NAME} with \"$APP_SHORT_NAME\" in $PREINST_FILE"
chmod +x "$PREINST_FILE"

# build pkg
cd ..
pkgbuild \
  --root ./project/payload \
  --scripts ./project/scripts \
  --identifier "$APP_NAME" \
  --version "$APP_VERSION" \
  --install-location /Applications \
  ./build/${FILE_APP_NAME}-macos-installer-${arch}-${APP_VERSION}.pkg

# copy to releases folder
cp ./build/${FILE_APP_NAME}-macos-installer-${arch}-${APP_VERSION}.pkg ../releases/macos/