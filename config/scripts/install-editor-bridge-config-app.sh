#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${EDITOR_BRIDGE_CONFIG_APP_NAME:-Editor Bridge.app}"
APP_PATH="${EDITOR_BRIDGE_CONFIG_APP_PATH:-$HOME/Applications/$APP_NAME}"
APP_DIR="$(dirname "$APP_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INFO_PLIST_SOURCE="$SCRIPT_DIR/apps/editor-bridge-config-info.plist"

swift build --package-path "$SCRIPT_DIR" -c release --product EditorBridgeApp >/dev/null
BIN_DIR="$(swift build --package-path "$SCRIPT_DIR" -c release --product EditorBridgeApp --show-bin-path)"
EXECUTABLE="$BIN_DIR/EditorBridgeApp"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*_EditorBridgeApp.bundle' | head -n1)"

if [ ! -x "$EXECUTABLE" ]; then
  echo "failed to build EditorBridgeApp" >&2
  exit 1
fi

mkdir -p "$APP_DIR"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/Editor Bridge"
cp "$INFO_PLIST_SOURCE" "$APP_PATH/Contents/Info.plist"

if [ -n "$RESOURCE_BUNDLE" ] && [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" >/dev/null 2>&1 || true
mdimport "$APP_PATH" >/dev/null 2>&1 || true

echo "$APP_PATH"
