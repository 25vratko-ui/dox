#!/usr/bin/env bash
# Builds a release binary and wraps it into build/Dox.app (ad-hoc signed) + build/Dox.zip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="build/Dox.app"
CONTENTS="$APP/Contents"

echo "==> swift build -c release"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/Dox"
if [[ ! -x "$BINARY" ]]; then
  BINARY=".build/release/Dox"
fi

echo "==> Assembling $APP"
rm -rf "$APP" build/Dox.zip
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/Dox"
cp Resources/Info.plist "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Ad-hoc signing"
codesign --force --deep -s - "$APP"

echo "==> Zipping"
ditto -c -k --keepParent "$APP" build/Dox.zip

echo "Done: $APP, build/Dox.zip"
