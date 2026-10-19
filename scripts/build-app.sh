#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/dist/Webshare Manager.app"
mkdir -p "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto Resources "$APP/Contents/Resources"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp Assets/WebshareManager.icns "$APP/Contents/Resources/WebshareManager.icns"
cp "$BIN_DIR/Webshare" "$APP/Contents/MacOS/Webshare"
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp -f .build/checkouts/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE.txt"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Webshare</string>
<key>CFBundleIdentifier</key><string>cz.local.webshare.mac</string>
<key>CFBundleName</key><string>Webshare Manager</string>
<key>CFBundleDisplayName</key><string>Webshare Manager</string>
<key>CFBundleIconFile</key><string>WebshareManager</string>
<key>CFBundleDevelopmentRegion</key><string>cs</string>
<key>CFBundleLocalizations</key><array><string>cs</string><string>sk</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.8.1</string>
<key>CFBundleVersion</key><string>15</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
python3 scripts/configure-updater.py "$APP"
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" "$PWD/dist/Webshare-Manager-macOS.zip"
print "Hotovo: $APP"
