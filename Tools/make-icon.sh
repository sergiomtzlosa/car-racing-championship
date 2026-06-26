#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/Tools/icon_master.png"
ICONSET="$ROOT/Tools/AppIcon.iconset"
ASSETS="$ROOT/ApexSlotRacing/Resources/Assets.xcassets/AppIcon.appiconset"
RESOURCES="$ROOT/ApexSlotRacing/Resources"

mkdir -p "$ASSETS" "$RESOURCES"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

xcrun swift "$ROOT/Tools/make-icon.swift" "$MASTER"

cp_size() {
  local size="$1"; local file="$2"
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$file" >/dev/null
  sips -z "$size" "$size" "$MASTER" --out "$ASSETS/$file" >/dev/null
}
cp_size 16 "icon_16x16.png"
cp_size 32 "icon_16x16@2x.png"
cp_size 32 "icon_32x32.png"
cp_size 64 "icon_32x32@2x.png"
cp_size 128 "icon_128x128.png"
cp_size 256 "icon_128x128@2x.png"
cp_size 256 "icon_256x256.png"
cp_size 512 "icon_256x256@2x.png"
cp_size 512 "icon_512x512.png"
cp_size 1024 "icon_512x512@2x.png"

cat > "$ASSETS/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

echo "Generated AppIcon.icns and AppIcon.appiconset"
sips -g pixelWidth -g pixelHeight "$RESOURCES/AppIcon.icns" | tail -2
