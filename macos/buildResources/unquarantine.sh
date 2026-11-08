#!/bin/sh

xattr -d com.apple.quarantine './%%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg'
