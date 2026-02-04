#!/bin/zsh
set -euo pipefail

SIM_ID=$(./scripts/select_simulator.sh)
if [[ -z "$SIM_ID" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

./scripts/boot_simulator.sh

DERIVED_DATA=.build
xcodebuild -scheme LanguageReader -destination "id=$SIM_ID" -derivedDataPath "$DERIVED_DATA" build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LanguageReader.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at $APP_PATH"
  exit 1
fi

xcrun simctl install "$SIM_ID" "$APP_PATH"
BUNDLE_ID="com.local.LanguageReader"
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
