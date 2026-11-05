#!/usr/bin/env bash
# Builds markdownToPdf.app (universal: Apple silicon + Intel) and a zip for releases.
#
#   scripts/build-app.sh            -> build/markdownToPdf.app + dist/markdownToPdf-<version>.zip
#   scripts/build-app.sh --native   -> only the architecture of this Mac (faster)
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="markdownToPdf"
VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="build/${APP_NAME}.app"

if [[ "${1:-}" == "--native" ]]; then
  ARCHS=("$(uname -m)")
else
  ARCHS=(arm64 x86_64)
fi

echo "==> Building ${APP_NAME} ${VERSION} (${ARCHS[*]})"
BINARIES=()
for arch in "${ARCHS[@]}"; do
  swift build -c release --arch "$arch" --product MarkdownToPdf
  BINARIES+=("$(swift build -c release --arch "$arch" --show-bin-path)/MarkdownToPdf")
done

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/${APP_NAME}"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Web/* "$APP/Contents/Resources/"
sed -e "s/__VERSION__/${VERSION}/" -e "s/__BUILD__/${BUILD_NUMBER}/" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --verbose "$APP"

echo "==> Packaging"
mkdir -p dist
ZIP="dist/${APP_NAME}-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"

echo "==> Done: $APP and $ZIP"
