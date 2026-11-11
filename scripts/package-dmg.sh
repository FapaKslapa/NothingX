#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
APP="build/Nothing X.app"
DMG="build/NothingX-$VERSION.dmg"
[[ -d "$APP" ]] || { echo "error: run ./build.sh first" >&2; exit 66; }
rm -rf build/dmg "$DMG"
mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "Nothing X" -srcfolder build/dmg -fs HFS+ -format UDZO -ov "$DMG"
echo "$DMG"
