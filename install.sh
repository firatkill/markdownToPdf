#!/usr/bin/env bash
# Installs the latest markdownToPdf release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/firatkill/markdownToPdf/main/install.sh | bash
set -euo pipefail

REPO="firatkill/markdownToPdf"
APP_NAME="markdownToPdf.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "markdownToPdf is a macOS app." >&2
  exit 1
fi

echo "==> Looking up the latest release of ${REPO}"
ZIP_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -Eo '"browser_download_url": *"[^"]+\.zip"' \
  | head -n 1 \
  | sed -E 's/.*"(https[^"]+)"/\1/')"

if [[ -z "$ZIP_URL" ]]; then
  echo "Could not find a release download. See https://github.com/${REPO}/releases" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading ${ZIP_URL##*/}"
curl -fL --progress-bar "$ZIP_URL" -o "$TMP/app.zip"
ditto -x -k "$TMP/app.zip" "$TMP"

TARGET_DIR="/Applications"
if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi

echo "==> Installing to ${TARGET_DIR}/${APP_NAME}"
osascript -e 'quit app "markdownToPdf"' >/dev/null 2>&1 || true
rm -rf "${TARGET_DIR:?}/${APP_NAME}"
ditto "$TMP/${APP_NAME}" "${TARGET_DIR}/${APP_NAME}"
# The app is not notarized; clear the download flag so Gatekeeper lets it open.
xattr -dr com.apple.quarantine "${TARGET_DIR}/${APP_NAME}" 2>/dev/null || true

echo "==> Done. Opening markdownToPdf…"
open "${TARGET_DIR}/${APP_NAME}"
