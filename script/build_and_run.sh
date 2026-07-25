#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="NotchDo"
BUNDLE_ID="com.luku.NotchDo"
BUILD_CONFIGURATION="release"

if [[ "$MODE" == "--debug" || "$MODE" == "debug" ]]; then
    BUILD_CONFIGURATION="debug"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build \
    --package-path "$ROOT_DIR" \
    --configuration "$BUILD_CONFIGURATION" \
    --product "$APP_NAME"
BUILD_BINARY="$(swift build \
    --package-path "$ROOT_DIR" \
    --configuration "$BUILD_CONFIGURATION" \
    --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Support/Info.plist" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_BINARY"
codesign \
    --force \
    --sign - \
    --identifier "$BUNDLE_ID" \
    --requirements "=designated => identifier \"$BUNDLE_ID\"" \
    --entitlements "$ROOT_DIR/Support/NotchDo.entitlements" \
    "$APP_BUNDLE"

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
