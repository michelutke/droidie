#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/Droidie.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Droidie "$APP/Contents/MacOS/Droidie"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Droidie</string>
    <key>CFBundleIdentifier</key><string>com.miggi.droidie</string>
    <key>CFBundleName</key><string>Droidie</string>
    <key>CFBundleDisplayName</key><string>Droidie</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string></string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"
