#!/bin/bash
# Post-install script for installer

# Set install directory to /Applications/%%APP_NAME%%.app
INSTALL_DIR="/Applications/%%APP_NAME%%.app"

# Ensure the start-%%FILE_APP_NAME%%.zsh, find_free_port.sh and server.bin scripts are executable
chmod +x "$INSTALL_DIR/Contents/MacOS/start-%%FILE_APP_NAME%%.sh"
chmod +x "$INSTALL_DIR/Contents/MacOS/find_free_port.sh"
chmod +x "$INSTALL_DIR/Contents/bin/server.bin"

exit 0