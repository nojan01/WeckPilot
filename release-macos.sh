#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IDENTITY="Developer ID Application: Norbert Jander (TXF2V79Z6N)"
NOTARY_PROFILE="DesktopProfileManager"
VERSION="$(node -p "require('$PROJECT_DIR/package.json').version")"
BUNDLE_DIR="$PROJECT_DIR/src-tauri/target/release/bundle"
APP_PATH="$BUNDLE_DIR/macos/AlarmMaster.app"
DMG_DIR="$BUNDLE_DIR/dmg"
DMG_PATH="$DMG_DIR/AlarmMaster_${VERSION}_aarch64.dmg"
NOTARY_ZIP="$BUNDLE_DIR/AlarmMaster_${VERSION}_aarch64-notarization.zip"
STAGING_DIR="$(mktemp -d /tmp/alarmmaster-dmg.XXXXXX)"

cleanup() {
  rm -rf -- "$STAGING_DIR"
  rm -f -- "$NOTARY_ZIP"
}
trap cleanup EXIT

cd "$PROJECT_DIR"

echo "Baue AlarmMaster ${VERSION} ..."
npm run tauri:build -- --bundles app

echo "Signiere die App mit der Developer ID ..."
codesign --force --deep --options runtime --timestamp \
  --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Notarisiere die App ..."
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo "Erstelle das DMG ..."
mkdir -p "$DMG_DIR"
ditto "$APP_PATH" "$STAGING_DIR/AlarmMaster.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f -- "$DMG_PATH"
hdiutil create -volname "AlarmMaster" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH"

echo "Signiere und notarisiere das DMG ..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
codesign --verify --deep --strict --verbose=2 "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature \
  --verbose=2 "$DMG_PATH"

echo "Fertig: $DMG_PATH"
