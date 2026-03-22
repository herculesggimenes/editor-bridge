#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${DEV_EDITOR_APP_NAME:-Dev Editor.app}"
APP_PATH="${DEV_EDITOR_APP_PATH:-$HOME/Applications/$APP_NAME}"
APP_DIR="$(dirname "$APP_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$SCRIPT_DIR/apps/dev-editor.applescript"
BUNDLE_FRAGMENT="$SCRIPT_DIR/apps/dev-editor-info.plist"
BUNDLE_FRAGMENT_EXTRA="${DEV_EDITOR_BUNDLE_FRAGMENT_EXTRA:-}"
BUNDLE_ID="${DEV_EDITOR_BUNDLE_ID:-dev.editorbridge.deveditor}"

plist_set() {
  local key="$1"
  local type="$2"
  local value="$3"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$PLIST"
  fi
}

plist_delete_if_exists() {
  local key="$1"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Delete :$key" "$PLIST"
  fi
}

mkdir -p "$APP_DIR"
rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "$SOURCE"

PLIST="$APP_PATH/Contents/Info.plist"
plist_delete_if_exists "CFBundleDocumentTypes"
plist_delete_if_exists "UTExportedTypeDeclarations"
/usr/libexec/PlistBuddy -c "Merge $BUNDLE_FRAGMENT :" "$PLIST"
if [ -n "$BUNDLE_FRAGMENT_EXTRA" ] && [ -f "$BUNDLE_FRAGMENT_EXTRA" ]; then
  if /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" "$BUNDLE_FRAGMENT_EXTRA" >/dev/null 2>&1; then
    plist_delete_if_exists "CFBundleDocumentTypes"
  fi
  if /usr/libexec/PlistBuddy -c "Print :UTExportedTypeDeclarations" "$BUNDLE_FRAGMENT_EXTRA" >/dev/null 2>&1; then
    plist_delete_if_exists "UTExportedTypeDeclarations"
  fi
  /usr/libexec/PlistBuddy -c "Merge $BUNDLE_FRAGMENT_EXTRA :" "$PLIST"
fi
plist_set "CFBundleIdentifier" string "$BUNDLE_ID"
plist_set "CFBundleName" string "Dev Editor"
plist_set "LSUIElement" bool true

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" >/dev/null 2>&1 || true
mdimport "$APP_PATH" >/dev/null 2>&1 || true

echo "$APP_PATH"
