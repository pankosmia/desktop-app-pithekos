#!/usr/bin/env zsh

set -e
set -u

echo

# Do not ask if the server is off if the -s argument is provided
# Specify environment as an optional non-flag argument: dev, qa, or main (default: main)
# Specify log level as an optional non-flag argument: critical, normal, debug, or off (default: normal)
envArg=""
logArg=""
while [[ "$#" -gt 0 ]]
  do case $1 in
      -s) askIfOff="$1" # -s means "no"
      ;;
      *) if [[ "$1" != -* ]]; then
           if [ -z "$logArg" ] && { [ "$1" = "critical" ] || [ "$1" = "normal" ] || [ "$1" = "debug" ] || [ "$1" = "off" ]; }; then
             logArg="$1"
           elif [ -z "$envArg" ]; then
             envArg="$1"
           fi
         fi
      ;;
  esac
  shift
done

# Normalize: anything other than critical, debug, or off is treated as normal
if [ -z "$logArg" ]; then
  logArg="normal"
fi
if [ "$logArg" != "critical" ] && [ "$logArg" != "debug" ] && [ "$logArg" != "off" ]; then
  logArg="normal"
fi

# Rewrite the log level in Rocket.toml (read at run time, so the change is left in place)
rocketFile="../../Rocket.toml"

echo "  Using log level \"$logArg\""
sed -i '' "s|^log_level = \"[^\"]*\"|log_level = \"$logArg\"|" "$rocketFile"

# Normalize: anything other than dev or qa is treated as main
if [ -z "$envArg" ]; then
  envArg="main"
fi
if [ "$envArg" != "dev" ] && [ "$envArg" != "qa" ]; then
  envArg="main"
fi

# For dev and qa, back up Cargo.toml and rewrite the pankosmia_web version
# For main, Cargo.toml already has the correct version — no replacement needed
cargoFile="../../local_server/Cargo.toml"
cargoBackup="../../local_server/Cargo.toml.bak"
didRewriteCargo=0

restore_cargo() {
  if [ "$didRewriteCargo" -eq 1 ] && [ -f "$cargoBackup" ]; then
    cp "$cargoBackup" "$cargoFile"
    rm "$cargoBackup"
  fi
}
trap restore_cargo EXIT

if [ "$envArg" != "main" ]; then
  targetVersion=$(grep "^${envArg}=" "../../local_server.env" | cut -d'=' -f2)
  if [ -z "$targetVersion" ]; then
    echo "  Could not find environment \"$envArg\" in local_server.env"
    exit 1
  fi
  echo "  Using pankosmia_web version $targetVersion for environment \"$envArg\""
  cp "$cargoFile" "$cargoBackup"
  sed -i '' "s|pankosmia_web = \"=[^\"]*\"|pankosmia_web = \"=$targetVersion\"|" "$cargoFile"
  didRewriteCargo=1
else
  echo "  Using pankosmia_web version from Cargo.toml (main)"
fi

# Assign default value if -s is not present
if [ -z ${askIfOff+x} ]; then # askIfOff is unset
  askIfOff=-yes
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

# Build the rust server (always release)
echo "Building local Release server at /local_server/target/release ..."
cd ../../local_server
echo "cargo build --release"
OPENSSL_STATIC=yes cargo build --release
cd ../macos/scripts

# Cargo.toml is restored by the EXIT trap

if [ -d ../build ]; then
  echo "Removing last build environment..."
  echo
  rm -rf ../build
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment"
  node ./build.js
fi
