#!/bin/bash
#
# snapshot.sh - deterministic screenshot harness.
#
# Builds the app, installs it on a simulator, and deep-links into each screen
# via the DEBUG-only `-uiTestScreen` launch argument, capturing one PNG per
# screen and appearance under Screenshots/. Re-run any time to refresh the
# baseline and eyeball UI changes.
#
# Usage:
#   Scripts/snapshot.sh                 # capture / update baselines
#   Scripts/snapshot.sh --verify        # compare against committed baselines
#   SIM_DEVICE="iPhone 17 Pro" Scripts/snapshot.sh
#   SCREENS="settings defaults" APPEARANCES="light" Scripts/snapshot.sh
#
set -euo pipefail

PROJECT="HatGame/HatGame.xcodeproj"
SCHEME="HatGame"
BUNDLE_ID="com.khizanag.hat-game"
OUTPUT_DIR="Screenshots"
SETTLE_SECONDS="${SETTLE_SECONDS:-2.5}"
read -r -a SCREENS <<< "${SCREENS:-home settings defaults appIcon}"
read -r -a APPEARANCES <<< "${APPEARANCES:-light dark}"

MODE="capture"
[[ "${1:-}" == "--verify" ]] && MODE="verify"

cd "$(dirname "$0")/.."

UDID_RE='[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}'
if [[ -n "${SIM_DEVICE:-}" ]]; then
  echo "==> Resolving simulator '$SIM_DEVICE'"
  UDID=$(xcrun simctl list devices available | grep "$SIM_DEVICE (" | head -1 | grep -oiE "$UDID_RE" || true)
else
  echo "==> Resolving first available iOS 26 simulator"
  UDID=$(xcrun simctl list devices available \
    | awk '/-- iOS 26/{f=1;next} /^-- /{f=0} f && /\(Shutdown\)|\(Booted\)/{print;exit}' \
    | grep -oiE "$UDID_RE" || true)
fi
[[ -n "$UDID" ]] || { echo "No suitable iOS 26 simulator found (set SIM_DEVICE=...)." >&2; exit 1; }
echo "    $UDID"

echo "==> Booting"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || true

echo "==> Building (Debug)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "id=$UDID" build \
  > /tmp/snapshot-build.log 2>&1 || { tail -40 /tmp/snapshot-build.log; exit 1; }

APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "id=$UDID" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR =/{print $2; exit}')/HatGame.app"
echo "==> Installing $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"

if [[ "$MODE" == "verify" ]]; then
  CAPTURE_DIR="$(mktemp -d)"
  echo "==> Capturing and comparing against baselines in $OUTPUT_DIR/"
else
  CAPTURE_DIR="$OUTPUT_DIR"
  mkdir -p "$CAPTURE_DIR"
  echo "==> Capturing baselines into $OUTPUT_DIR/"
fi

for appearance in "${APPEARANCES[@]}"; do
  xcrun simctl ui "$UDID" appearance "$appearance" >/dev/null 2>&1 || true
  for screen in "${SCREENS[@]}"; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
      -uiTestScreen "$screen" \
      -uiTestColorScheme "$appearance" \
      -uiTestDisableAnimations >/dev/null
    sleep "$SETTLE_SECONDS"
    xcrun simctl io "$UDID" screenshot "$CAPTURE_DIR/${screen}-${appearance}.png" >/dev/null
    [[ "$MODE" == "verify" ]] || echo "    ok  $OUTPUT_DIR/${screen}-${appearance}.png"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

if [[ "$MODE" != "verify" ]]; then
  echo "==> Done -> $OUTPUT_DIR/"
  exit 0
fi

DIFF_DIR="$OUTPUT_DIR/.diffs"
rm -rf "$DIFF_DIR"
mkdir -p "$DIFF_DIR"
failures=0
for shot in "$CAPTURE_DIR"/*.png; do
  name="$(basename "$shot")"
  baseline="$OUTPUT_DIR/$name"
  if [[ ! -f "$baseline" ]]; then
    echo "    NEW   $name (no baseline)"
    failures=$((failures + 1))
    continue
  fi
  if detail=$(swift Scripts/compare-images.swift "$baseline" "$shot" "$DIFF_DIR/$name" 2>&1); then
    echo "    PASS  $name  $detail"
  else
    echo "    FAIL  $name  $detail"
    failures=$((failures + 1))
  fi
done
rm -rf "$CAPTURE_DIR"

if [[ "$failures" -eq 0 ]]; then
  rmdir "$DIFF_DIR" 2>/dev/null || true
  echo "==> All snapshots match their baselines."
else
  echo "==> $failures snapshot(s) changed -> diff images in $DIFF_DIR/" >&2
  exit 1
fi
