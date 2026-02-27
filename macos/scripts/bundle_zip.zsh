#!/usr/bin/env zsh

# This script uses the APP_VERSION and APP_NAME environment variables as defined in app_config.env

# run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./bundle_tgz.zsh

set -e
set -u

echo

# Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
# Github Actions specified if the -g positional argument is provided in either #1 or #2
while [[ "$#" -gt 0 ]]
  do case $1 in
      -s) askIfOff="$1"  # -s means "no"
      ;;
      -g) isGHA="$1" # -g means "yes"
  esac
  shift
done

# Assign default value if -s is not present
if [ -z ${askIfOff+x} ]; then # askIfOff is unset"
  askIfOff=-yes
fi

# Assign default value if -g is not present
if [ -z ${isGHA+x} ]; then # isGHA is unset
  isGHA=-no
fi

if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Is the server off? [Y/n]: "
    case $choice in 
      "y" | "Y" | "" ) echo
        echo "Continuing...";
        break
        ;;
      [nN] ) echo;
        echo "     Exiting...";
        echo;
        echo "     If the server is on, turn it off with Ctrl-C in the terminal window in which it is running, then re-run this script.";
        echo;
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.";
        echo
        ;;
    esac
  done
fi

# In GHA, each step has either already run or is otherwise unnecessary.
if ! [[ $isGHA =~ ^(-g) ]]; then
  cd ../../
  if [ $(ls releases/macos/*.zip 2>/dev/null | wc -l) -gt 0 ]; then
    echo "A previous macos .zip release exists. Removing..."
    rm releases/macos/*.zip
  fi
  # echo "checkout main"
  # git checkout main &> /dev/null
  # echo "pull"
  # git pull
  # echo "npm ci"
  # npm ci
  cd macos/scripts
  echo
  echo "Running app_setup to ensure version number consistency between buildSpec.json and this build bundle:"
  ./app_setup.zsh
fi

source ../../app_config.env
echo
echo "Version is $APP_VERSION"
echo

if ! [[ $isGHA =~ ^(-g) ]]; then
  if [ -f ../build ]; then
    echo "Removing last build environment"
    rm -rf ../build
  fi
  echo "Assembling build environment"
  node build.js
fi

# Detect current CPU architecture
CPU_ARCH=$(uname -m)
if [ "$CPU_ARCH" = "x86_64" ]; then
    CPU_ARCH="intel64"
elif [ "$CPU_ARCH" = "arm64" ]; then
    CPU_ARCH="arm64"
else
    echo "Error: Unsupported CPU architecture: $CPU_ARCH, default to intel64"
    CPU_ARCH="intel64"
fi

echo
echo "   **********************************"
echo "   *                                *"
echo "   *           ====                 *"
echo "   * Bundling. Wait for the prompt. *"
echo "   *           ====                 *"
echo "   *                                *"
echo "   **********************************"
echo
cd ../build
# Use lower case app name in filename
APP_NAME=${APP_NAME:l}
# Replace spaces with a dash (-) in filename
APP_NAME=${APP_NAME// /-}
# Make executable and zip
chmod +x $APP_NAME.zsh
zip -r ../../releases/macos/$APP_NAME-macos-$CPU_ARCH-$APP_VERSION.zip * -x post_install_script.sh appLauncher.sh @ &> /dev/null
cd ../scripts
