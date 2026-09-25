#!/usr/bin/env bash
# Generates App Store / Google Play screenshots of the tuner.
#
#   tool/store_screenshots/generate.sh                # en + zh_TW, all devices
#   tool/store_screenshots/generate.sh en de fr       # chosen locales
#   DEVICES=android_phone tool/store_screenshots/generate.sh en
#
# Output: store/screenshots/<device>/<locale>/NN_scene.png — opaque RGB PNGs at
# the exact store pixel sizes. Needs Flutter, curl, and python3 with Pillow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-$(command -v flutter || echo ../flutter/bin/flutter)}"
FLUTTER_ROOT="$(cd "$(dirname "$(readlink -f "$FLUTTER")")/.." && pwd)"
ICON_FONT="$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
FONT_DIR="${FONT_DIR:-$ROOT/build/store_screenshots/fonts}"
RAW_DIR="$ROOT/build/store_screenshots/raw"
OUT_DIR="$ROOT/store/screenshots"

LOCALES=("$@")
[ ${#LOCALES[@]} -eq 0 ] && LOCALES=(en zh_TW)

python3 -c "import PIL" 2>/dev/null || { echo "Needs Pillow: pip install pillow" >&2; exit 1; }

# Fonts — the same Google Fonts the app downloads at runtime, plus Noto Sans
# TC/SC as the ♭/♯ and CJK fallback.
mkdir -p "$FONT_DIR"
if [ ! -f "$FONT_DIR/NotoSansSC-700.ttf" ]; then
  curl -fsS "https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=Noto+Sans+TC:wght@400;500;700&family=Noto+Sans+SC:wght@400;500;700" |
    python3 -c "
import re, sys
css = sys.stdin.read()
for fam, w, url in re.findall(r\"font-family: '([^']+)';\s*font-style: normal;\s*font-weight: (\d+);\s*src: url\(([^)]+)\)\", css):
    print(fam.replace(' ', '') + '-' + w + '.ttf', url)
" | while read -r name url; do curl -fsS -o "$FONT_DIR/$name" "$url"; done
fi

rm -rf "$RAW_DIR"
for locale in "${LOCALES[@]}"; do
  echo "── $locale"
  "$FLUTTER" test tool/store_screenshots/store_screenshots_test.dart \
    --dart-define=FONT_DIR="$FONT_DIR" \
    --dart-define=ICON_FONT="$ICON_FONT" \
    --dart-define=OUT_DIR="$RAW_DIR" \
    --dart-define=LOCALE="$locale" \
    --dart-define=DEVICES="${DEVICES:-}"
done

# Stores reject alpha channels (Play: "24-bit PNG, no alpha"): flatten to RGB
# and check every image is exactly its store size.
python3 - "$RAW_DIR" "$OUT_DIR" <<'PY'
import pathlib, sys
from PIL import Image
sizes = {
    "ios_iphone_6.9": (1320, 2868),
    "ios_iphone_6.5": (1284, 2778),
    "ios_ipad_13": (2064, 2752),
    "android_phone": (1080, 1920),
}
raw, out = map(pathlib.Path, sys.argv[1:])
count = 0
for src in sorted(raw.rglob("*.png")):
    rel = src.relative_to(raw)
    img = Image.open(src)
    want = sizes[rel.parts[0]]
    if img.size != want:
        sys.exit(f"{rel}: {img.size} != {want}")
    dst = out / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(dst, optimize=True)
    count += 1
print(f"{count} screenshots → {out}")
PY
