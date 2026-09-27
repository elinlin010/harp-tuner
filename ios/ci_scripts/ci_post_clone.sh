#!/bin/sh
set -e

# ── Install Flutter ────────────────────────────────────────────────────────────
# Must satisfy the `sdks:` floor in pubspec.lock (currently Dart >=3.12,
# Flutter >=3.44). Bump this whenever a dependency upgrade raises that floor,
# or `flutter pub get` below fails with "version solving failed".
FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version

# ── Flutter setup ──────────────────────────────────────────────────────────────
# Run from repo root (Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH)
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get
flutter precache --ios

# ── CocoaPods ─────────────────────────────────────────────────────────────────
cd ios
pod install

echo "ci_post_clone.sh complete"
