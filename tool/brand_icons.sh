#!/usr/bin/env bash
# Regenerates the app icons from brand/icon.svg.
#
# Android's launcher icon is an adaptive icon drawn from a vector, so it is
# every size at once and nothing here makes it. The bitmaps below are only the
# fallback any surface that ignores adaptive icons falls back to — left as
# Flutter's own logo they would be a stranger's icon in a corner of the app.
#
# qlmanage is macOS's own renderer and the only one this machine has. It writes
# <name>.svg.png next to the output directory, so each size is rendered and
# renamed in turn.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="brand/icon.svg"
OUT="ios/Runner/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# size:filename, straight from the appiconset's Contents.json
for pair in \
  20:Icon-App-20x20@1x 40:Icon-App-20x20@2x 60:Icon-App-20x20@3x \
  29:Icon-App-29x29@1x 58:Icon-App-29x29@2x 87:Icon-App-29x29@3x \
  40:Icon-App-40x40@1x 80:Icon-App-40x40@2x 120:Icon-App-40x40@3x \
  120:Icon-App-60x60@2x 180:Icon-App-60x60@3x \
  76:Icon-App-76x76@1x 152:Icon-App-76x76@2x \
  167:Icon-App-83.5x83.5@2x 1024:Icon-App-1024x1024@1x
do
  size="${pair%%:*}"; name="${pair##*:}"
  qlmanage -t -s "$size" -o "$TMP" "$SRC" >/dev/null 2>&1
  sips -z "$size" "$size" "$TMP/icon.svg.png" --out "$OUT/$name.png" >/dev/null
  rm -f "$TMP/icon.svg.png"
  echo "  $name.png  ${size}x${size}"
done
echo "iOS icons written to $OUT"

# Android's fallback bitmaps, one per density bucket.
for pair in 48:mdpi 72:hdpi 96:xhdpi 144:xxhdpi 192:xxxhdpi; do
  size="${pair%%:*}"; density="${pair##*:}"
  dir="android/app/src/main/res/mipmap-$density"
  qlmanage -t -s "$size" -o "$TMP" "$SRC" >/dev/null 2>&1
  sips -z "$size" "$size" "$TMP/icon.svg.png" --out "$dir/ic_launcher.png" >/dev/null
  rm -f "$TMP/icon.svg.png"
  echo "  mipmap-$density/ic_launcher.png  ${size}x${size}"
done
