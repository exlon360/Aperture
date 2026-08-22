#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_BUNDLE="$PROJECT_ROOT/dist/Aperture.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"

cd "$PROJECT_ROOT"
swift build -c release

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$PROJECT_ROOT/.build/release/Aperture" "$CONTENTS_DIR/MacOS/Aperture"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$CONTENTS_DIR/MacOS/Aperture"

codesign --force --deep --sign - "$APP_BUNDLE"
echo "$APP_BUNDLE"
