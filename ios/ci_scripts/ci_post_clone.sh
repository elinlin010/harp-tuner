#!/bin/sh
set -e

# ── Install Flutter ────────────────────────────────────────────────────────────
FLUTTER_VERSION="3.41.6"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

# ── Flutter setup ──────────────────────────────────────────────────────────────
# Run from repo root (Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH)
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# ── CocoaPods ─────────────────────────────────────────────────────────────────
cd ios
pod install

echo "ci_post_clone.sh complete"
