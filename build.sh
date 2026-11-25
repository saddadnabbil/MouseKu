#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP=build/MouseKu.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos14.0" Sources/*.swift -o "build/MouseKu-$arch"
done
lipo -create build/MouseKu-arm64 build/MouseKu-x86_64 -output "$APP/Contents/MacOS/MouseKu"
rm build/MouseKu-arm64 build/MouseKu-x86_64
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.mouseku</string>
  <key>CFBundleName</key><string>MouseKu</string>
  <key>CFBundleExecutable</key><string>MouseKu</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
# Hardened runtime blocks library injection into a process that holds Accessibility access.
codesign --force --options runtime --sign - "$APP"
echo "OK: $PWD/$APP"
