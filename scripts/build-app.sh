#!/bin/bash
# Builds a universal (Apple Silicon + Intel) ScrollSplit.app and a zip for release.
# Usage: scripts/build-app.sh            -> build/ScrollSplit.app, build/ScrollSplit.zip
#        SIGN_IDENTITY=<cert SHA-1 or name> scripts/build-app.sh
#        Sign local builds with one fixed certificate so the Accessibility permission survives rebuilds
#        (ad-hoc signatures change with every build). Release builds stay ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ScrollSplit"

APP=build/ScrollSplit.app
rm -rf "$APP" build/ScrollSplit.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ScrollSplit"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature by default (no Apple Developer ID). Gatekeeper will ask once on first launch.
# The bundle has a single executable; sign it explicitly (no --deep) and verify.
# Hardened Runtime blocks code injection (DYLD_INSERT_LIBRARIES etc.) that could borrow the Accessibility permission.
codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict --verbose=1 "$APP"

ditto -c -k --keepParent "$APP" build/ScrollSplit.zip
echo "Built $APP and build/ScrollSplit.zip"
