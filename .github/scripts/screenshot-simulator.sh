#!/usr/bin/env bash
# Boots the largest iPhone simulator available (6.9" for App Store screenshots) with a clean status bar
# and dark appearance. Tries installed Xcode versions newest first.
#
# Outputs (GITHUB_OUTPUT): id=<simulator udid>, name=<device name>
# Env (GITHUB_ENV):        DEVELOPER_DIR=<Xcode that owns the simulator>
set -uo pipefail

APPS_DIR=${APPS_DIR:-/Applications}

pick_device_type() {
  # Prints "<device type id> <runtime id> <device name>" for the best phone on the newest iOS runtime.
  xcrun simctl list runtimes available -j | python3 -c '
import json, sys
preferred = ["iPhone 17 Pro Max", "iPhone 16 Pro Max", "iPhone Air", "iPhone 16 Plus", "iPhone 15 Pro Max"]
runtimes = [r for r in json.load(sys.stdin).get("runtimes", []) if r.get("platform") == "iOS" and r.get("isAvailable")]
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
for runtime in reversed(runtimes):
    phones = {d["name"]: d["identifier"] for d in runtime.get("supportedDeviceTypes", []) if d.get("productFamily") == "iPhone"}
    for name in preferred:
        if name in phones:
            print(phones[name], runtime["identifier"], name)
            sys.exit(0)
sys.exit(1)
'
}

XCODES=$(printf "%s\n" "$APPS_DIR"/Xcode_*.app | grep -vi beta | python3 -c '
import re, sys
apps = [line.strip() for line in sys.stdin if line.strip()]
def version(path):
    match = re.search(r"Xcode_([0-9.]+)\.app", path)
    return [int(p) for p in match.group(1).strip(".").split(".")] if match else [0]
print("\n".join(sorted(apps, key=version, reverse=True)))
')

for app in $XCODES; do
  export DEVELOPER_DIR="$app/Contents/Developer"
  pick=$(pick_device_type) || continue
  # shellcheck disable=SC2086
  set -- $pick
  type_id=$1
  runtime_id=$2
  shift 2
  name="$*"
  echo "Using $(xcodebuild -version | head -1): $name on $runtime_id"
  udid=$(xcrun simctl create "Screenshots" "$type_id" "$runtime_id") || continue
  xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b || true
  xcrun simctl ui "$udid" appearance dark || true
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
  echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$GITHUB_ENV"
  echo "id=$udid" >> "$GITHUB_OUTPUT"
  echo "name=$name" >> "$GITHUB_OUTPUT"
  exit 0
done

echo "No installed Xcode has a large iPhone simulator on this runner." >&2
xcrun simctl list runtimes
exit 1
