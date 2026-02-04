#!/bin/zsh
set -euo pipefail

SIM_ID=$(./scripts/select_simulator.sh)
if [[ -z "$SIM_ID" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

if [[ ! -f data/alar.sqlite ]]; then
  ./scripts/build_dictionary.py
fi

# Ensure app is built and installed at least once
./scripts/run.sh

APP_ID="com.local.LanguageReader"
CONTAINER=$(xcrun simctl get_app_container "$SIM_ID" "$APP_ID" data)
if [[ -z "$CONTAINER" ]]; then
  echo "App container not found. Make sure the app is installed on the simulator."
  exit 1
fi

mkdir -p "$CONTAINER/Documents"
cp data/alar.sqlite "$CONTAINER/Documents/dictionary.sqlite"

echo "Installed dictionary to: $CONTAINER/Documents/dictionary.sqlite"
