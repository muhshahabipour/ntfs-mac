#!/bin/bash
# Builds and signs build/NTFS.app (app + privileged helper). Personal-use, Apple Development signing.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')}"
[ -n "$IDENTITY" ] || { echo "No Apple Development signing identity found" >&2; exit 1; }

CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" --product NTFSApp
swift build -c "$CONFIG" --product NTFSHelper
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/NTFS.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchDaemons" "$APP/Contents/Resources"
cp "$BIN/NTFSApp"    "$APP/Contents/MacOS/NTFS"
cp "$BIN/NTFSHelper" "$APP/Contents/MacOS/NTFSHelper"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/com.local.ntfs.helper.plist "$APP/Contents/Library/LaunchDaemons/com.local.ntfs.helper.plist"

codesign --force --options runtime -s "$IDENTITY" -i com.local.ntfs.helper "$APP/Contents/MacOS/NTFSHelper"
codesign --force --options runtime -s "$IDENTITY" -i com.local.ntfs "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Built $APP"
