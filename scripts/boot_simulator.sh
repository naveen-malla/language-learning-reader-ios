#!/bin/zsh
set -euo pipefail

SIM_ID=$(./scripts/select_simulator.sh)
if [[ -z "$SIM_ID" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

xcrun simctl boot "$SIM_ID" || true
open -a Simulator
xcrun simctl bootstatus "$SIM_ID" -b
