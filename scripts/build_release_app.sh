#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="${APP_NAME:-AiPaste}"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-com.huike.aipaste}"
VERSION="${1:-${VERSION:-0.1.0}}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${ROOT_DIR}/dist"
APP_ICON_PATH="${ROOT_DIR}/Assets/AppIcon.icns"

cd "${ROOT_DIR}"

swift build -c release --product "${APP_NAME}" >/dev/null
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Missing executable at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.zip"

rm -rf "${APP_DIR}" "${ZIP_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

ICON_PLIST_LINES=""
if [[ -f "${APP_ICON_PATH}" ]]; then
  cp "${APP_ICON_PATH}" "${RESOURCES_DIR}/AppIcon.icns"
  ICON_PLIST_LINES=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
fi

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${APP_BUNDLE_IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
${ICON_PLIST_LINES}
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${APP_DIR}" >/dev/null

mkdir -p "${DIST_DIR}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Built app bundle: ${APP_DIR}"
echo "Built release archive: ${ZIP_PATH}"
