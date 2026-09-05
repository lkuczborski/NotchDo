#!/usr/bin/env bash
set -euo pipefail

# Isolated feature-testing and recording build. Never use this artifact for distribution.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO="${1:-features}"
case "$SCENARIO" in features|first-list|permission) ;; *) echo "usage: $0 [features|first-list|permission]" >&2; exit 2 ;; esac
OUTPUT="${NOTCHDO_DEMO_OUTPUT:-/tmp/notchdo-demo}"
APP="$OUTPUT/NotchDo Demo.app"
swift build --package-path "$ROOT" --scratch-path "$OUTPUT/build" --configuration release -Xswiftc -DNOTCHDO_DEMO --product NotchDo
BIN="$(swift build --package-path "$ROOT" --scratch-path "$OUTPUT/build" --configuration release -Xswiftc -DNOTCHDO_DEMO --show-bin-path)/NotchDo"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchDoDemo"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Support/NotchDo.icns" "$APP/Contents/Resources/NotchDo.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.luku.NotchDo.Demo' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName NotchDo Demo' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable NotchDoDemo' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :NSRemindersFullAccessUsageDescription' "$APP/Contents/Info.plist"
# No Reminders entitlement or usage description. The production adapter is not compiled.
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
pkill -x NotchDoDemo >/dev/null 2>&1 || true
/usr/bin/open -n --env "NOTCHDO_DEMO_SCENARIO=$SCENARIO" "$APP"
sleep 1
pgrep -x NotchDoDemo >/dev/null
echo "Isolated demo running: $APP ($SCENARIO)"
