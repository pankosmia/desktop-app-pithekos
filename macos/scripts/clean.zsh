#!/usr/bin/env zsh

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
        echo "     If the server is on, turn it off with Ctrl-C in the terminal window in which it is running, then re-run this script."
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

if [ -d ../build ]; then
  echo
  echo
  echo "Removing last build environment"
  rm -rf ../build
fi

if [ -f ../../local_server/target/release/local_server ]; then
    echo
    echo
    echo "Cleaning local server"
    cd ../../local_server
    cargo clean
    cd ../macos/scripts
fi

echo
echo
echo "The local server and build environment have been cleaned."
echo
