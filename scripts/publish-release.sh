#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
# Commit source changes before publishing. Appcast is generated afterwards.
git diff --quiet
git diff --cached --quiet
./scripts/test.sh
./scripts/build-app.sh
python3 scripts/prepare-release.py
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'dist/Webshare Manager.app/Contents/Info.plist')
ASSET="dist/Webshare-Manager-$VERSION-arm64.zip"
gh release create "v$VERSION" "$ASSET" "$ASSET.sha256" --repo humaxdragon-bit/webshare-manager --target "$(git rev-parse HEAD)" --title "Webshare Manager $VERSION" --notes-file updates/release-notes.txt --prerelease
# Publish the feed only after the download exists.
git add updates/appcast.xml
git commit -m "Publish update feed for $VERSION"
git push origin HEAD:main
