#!/bin/sh

pkg="./%%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg"
backend="./bin/server.bin"

if [ -e "$pkg" ]; then
    xattr -d com.apple.quarantine "$pkg"
fi

if [ -e "$backend" ]; then
    xattr -d com.apple.quarantine "$backend"
fi