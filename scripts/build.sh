#!/bin/zsh
set -euo pipefail

SIM_ID=$(./scripts/select_simulator.sh)
if [[ -z "$SIM_ID" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

xcodebuild -scheme LanguageReader -destination "id=$SIM_ID" build
