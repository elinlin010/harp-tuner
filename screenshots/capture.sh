#!/bin/bash
DEVICE="2AFCF0E2-DF40-4767-BB77-6780CEB027C7"
DIR="$(dirname "$0")"

capture() {
  local name=$1
  local label=$2
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Screen $name: $label"
  echo "  Navigate to this state in Simulator,"
  echo "  then press ENTER to capture."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -r
  xcrun simctl io "$DEVICE" screenshot "$DIR/${name}.png"
  echo "  ✓ Saved ${name}.png"
}

echo ""
echo "Harpie — App Store Screenshot Capture"
echo "iPhone 17 Pro Max · 1320×2868"
echo ""

capture "01_main_idle" \
  "Main tuner, idle. Lever harp visible. 'Start Tuning' button at bottom."

capture "02_reference_mode" \
  "Reference mode. Tap the AUTO/REFERENCE toggle → switch to REFERENCE. Tap any string to select it (it plays a tone). String should be highlighted."

capture "03_settings" \
  "Settings sheet open. Tap the Settings button (top right) to open it. Scroll to show A4 calibration and string count."

capture "04_pedal_harp" \
  "Pedal harp layout. In Settings, switch harp type to Pedal Harp. Close Settings — the 47-string layout should fill the string list."

capture "05_gauge_active" \
  "Gauge active. Tap 'Start Tuning', hum or play a note near the mic. Needle deflected — showing a few cents sharp or flat."

echo ""
echo "All 5 screenshots captured in screenshots/"
echo "Check them with: open $DIR"
