#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchDo"

usage() {
    cat <<'EOF'
usage: script/release.sh <version> [options]

Build, Developer ID sign, notarize, staple, and validate a NotchDo release.

Arguments:
  <version>                    Release tag matching Info.plist, for example v0.1.0.

Options:
  --signing-identity <name>    Developer ID Application identity. Defaults to
                               NOTCHDO_SIGNING_IDENTITY.
  --notary-profile <name>      notarytool keychain profile. Defaults to
                               NOTCHDO_NOTARY_PROFILE.
  --skip-tests                 Skip the release test suite.
  --allow-dirty                Allow a dirty worktree for release-candidate checks.
  -h, --help                   Show this help.

Example:
  script/release.sh v0.1.0 \
    --signing-identity "Developer ID Application: Example (TEAMID)" \
    --notary-profile "notchdo"
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

VERSION=""
SIGNING_IDENTITY="${NOTCHDO_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTCHDO_NOTARY_PROFILE:-}"
SKIP_TESTS=0
ALLOW_DIRTY=0
TEMP_PATHS=()

cleanup() {
    local path
    (( ${#TEMP_PATHS[@]} == 0 )) && return

    for path in "${TEMP_PATHS[@]}"; do
        [[ -n "$path" ]] && rm -rf "$path"
    done
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --signing-identity)
            [[ $# -ge 2 ]] || die "--signing-identity requires a value"
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --notary-profile)
            [[ $# -ge 2 ]] || die "--notary-profile requires a value"
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        --allow-dirty)
            ALLOW_DIRTY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            [[ -z "$VERSION" ]] || die "multiple versions provided"
            VERSION="$1"
            shift
            ;;
    esac
done

[[ -n "$VERSION" ]] || die "version is required"
[[ "$VERSION" =~ ^v[0-9]+([.][0-9]+)*$ ]] || die "version must look like v0.1.0"
[[ -n "$SIGNING_IDENTITY" ]] || die \
    "set NOTCHDO_SIGNING_IDENTITY or pass --signing-identity"
[[ "$SIGNING_IDENTITY" == "Developer ID Application:"* ]] || die \
    "signing identity must be a Developer ID Application certificate"
[[ -n "$NOTARY_PROFILE" ]] || die \
    "set NOTCHDO_NOTARY_PROFILE or pass --notary-profile"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST_SOURCE="$ROOT_DIR/Support/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Support/NotchDo.entitlements"
ICON_SOURCE="$ROOT_DIR/Support/NotchDo.icns"
LICENSE_SOURCE="$ROOT_DIR/LICENSE"
RELEASE_ROOT="$ROOT_DIR/dist/release"
STAGE_ROOT="$RELEASE_ROOT/$VERSION"
PACKAGE_NAME="$APP_NAME-$VERSION-macos-universal"
PACKAGE_DIR="$STAGE_ROOT/$PACKAGE_NAME"
APP_BUNDLE="$PACKAGE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
ZIP_NAME="$PACKAGE_NAME.zip"
ZIP_PATH="$RELEASE_ROOT/$ZIP_NAME"
SHA_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"

require_command codesign
require_command ditto
require_command git
require_command lipo
require_command plutil
require_command security
require_command shasum
require_command spctl
require_command swift
require_command xcrun

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository"

if (( ! ALLOW_DIRTY )); then
    [[ -z "$(git status --porcelain)" ]] \
        || die "worktree is dirty; commit changes or use --allow-dirty"
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleShortVersionString" "$INFO_PLIST_SOURCE")"
PLIST_BUILD="$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleVersion" "$INFO_PLIST_SOURCE")"
[[ "${VERSION#v}" == "$PLIST_VERSION" ]] \
    || die "$VERSION does not match Info.plist version $PLIST_VERSION"

security find-identity -v -p codesigning \
    | grep -F "\"$SIGNING_IDENTITY\"" >/dev/null \
    || die "code-signing identity is not available: $SIGNING_IDENTITY"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null \
    || die "notarytool keychain profile is unavailable: $NOTARY_PROFILE"

if (( ! SKIP_TESTS )); then
    swift test --configuration release
fi

swift build \
    --configuration release \
    --arch arm64 \
    --arch x86_64 \
    --product "$APP_NAME"
BUILD_DIR="$(swift build \
    --configuration release \
    --arch arm64 \
    --arch x86_64 \
    --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

[[ -x "$BUILD_BINARY" ]] || die "missing built executable: $BUILD_BINARY"
ARCHITECTURES="$(lipo -archs "$BUILD_BINARY")"
[[ " $ARCHITECTURES " == *" arm64 "* ]] \
    || die "release executable is missing arm64: $ARCHITECTURES"
[[ " $ARCHITECTURES " == *" x86_64 "* ]] \
    || die "release executable is missing x86_64: $ARCHITECTURES"

rm -rf "$STAGE_ROOT"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$INFO_PLIST_SOURCE" "$APP_CONTENTS/Info.plist"
cp "$ICON_SOURCE" "$APP_RESOURCES/NotchDo.icns"
cp "$LICENSE_SOURCE" "$APP_RESOURCES/LICENSE"
cp "$LICENSE_SOURCE" "$PACKAGE_DIR/LICENSE"
chmod +x "$APP_BINARY"
plutil -lint "$APP_CONTENTS/Info.plist" "$ENTITLEMENTS" >/dev/null

codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign -dvvv "$APP_BUNDLE" 2>&1 \
    | grep -E 'flags=.*runtime' >/dev/null \
    || die "signed app is missing the hardened runtime flag"

rm -f "$ZIP_PATH" "$SHA_PATH"
(
    cd "$STAGE_ROOT"
    ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
)

xcrun notarytool submit \
    "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

rm -f "$ZIP_PATH"
(
    cd "$STAGE_ROOT"
    ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
)
(
    cd "$RELEASE_ROOT"
    shasum -a 256 "$ZIP_NAME" >"$SHA_PATH"
)

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/notchdo-release-verify.XXXXXX")"
TEMP_PATHS+=("$VERIFY_DIR")
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
EXTRACTED_APP="$VERIFY_DIR/$PACKAGE_NAME/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
xcrun stapler validate "$EXTRACTED_APP"
spctl --assess --type execute --verbose=4 "$EXTRACTED_APP"

cat <<EOF
Release package ready:
  $ZIP_PATH
  $SHA_PATH

Version:
  $PLIST_VERSION ($PLIST_BUILD)

Architectures:
  $ARCHITECTURES

SHA-256:
  $(cut -d ' ' -f 1 "$SHA_PATH")
EOF
