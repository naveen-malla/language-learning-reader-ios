#!/bin/zsh
set -euo pipefail

json=$(xcrun simctl list devices available -j)
SIM_JSON="$json" python3 - <<'PY'
import os
import json
import re
import sys

data = json.loads(os.environ.get("SIM_JSON", ""))

candidates = []
for runtime, devices in data.get("devices", {}).items():
    if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
        continue
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name", "")
        if not name.startswith("iPhone"):
            continue
        candidates.append((runtime, name, device.get("udid")))

if not candidates:
    print("")
    sys.exit(0)

# Prefer iPhone 14 Pro when available, otherwise pick the newest iPhone runtime.
for runtime, name, udid in candidates:
    if name == "iPhone 14 Pro":
        print(udid)
        sys.exit(0)

def runtime_version(rt: str):
    match = re.search(r"iOS-(\d+)-(\d+)", rt)
    if not match:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2)))

candidates.sort(key=lambda x: (runtime_version(x[0]), x[1]))
print(candidates[-1][2])
PY
