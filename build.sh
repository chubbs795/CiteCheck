#!/bin/bash
# Builds CiteCheck.app, installs (or updates) it in /Applications, and launches it.
# Requires Apple's Command Line Tools (run `xcode-select --install` once if needed).
set -euo pipefail
cd "$(dirname "$0")"

APP="CiteCheck.app"
EXEC="CiteCheck"
CERT_NAME="CenterWindows Local Signing"   # personal certificate created by the Centered installer

echo "Building…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARCH="$(uname -m)"
swiftc -O -swift-version 5 -target "${ARCH}-apple-macos13.0" \
  main.swift Model.swift Citation.swift CourtListener.swift Statute.swift StatuteVerifier.swift ContentView.swift \
  -o "$APP/Contents/MacOS/$EXEC" \
  -framework Cocoa -framework SwiftUI -framework Security
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/"

# Sign with your personal certificate if you have one, so the saved CourtListener
# token stays accessible after updates; otherwise use a simple local signature.
if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1 && codesign --force --sign "$CERT_NAME" "$APP" 2>/dev/null; then
  echo "Signed with your personal certificate."
else
  codesign --force --sign - "$APP"
fi

echo "Installing to /Applications…"
pkill -x "$EXEC" 2>/dev/null && sleep 0.5 || true
rm -rf "/Applications/$APP"
ditto "$APP" "/Applications/$APP"
xattr -cr "/Applications/$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP"

open "/Applications/$APP" || {
  echo "Finder launch failed; starting the app directly instead."
  nohup "/Applications/$APP/Contents/MacOS/$EXEC" >/dev/null 2>&1 &
}
echo "Done. CiteCheck is in your Applications folder."
