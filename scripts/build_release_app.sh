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
SPARKLE_APPCAST_URL="${SPARKLE_APPCAST_URL:-https://aipaste.github.io/AiPaste/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

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
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.zip"
SPARKLE_FRAMEWORK_SOURCE="${BIN_DIR}/Sparkle.framework"

rm -rf "${APP_DIR}" "${ZIP_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${FRAMEWORKS_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [[ ! -d "${SPARKLE_FRAMEWORK_SOURCE}" ]]; then
  echo "Missing Sparkle.framework at ${SPARKLE_FRAMEWORK_SOURCE}" >&2
  exit 1
fi

ditto "${SPARKLE_FRAMEWORK_SOURCE}" "${FRAMEWORKS_DIR}/Sparkle.framework"

ICON_PLIST_LINES=""
if [[ -f "${APP_ICON_PATH}" ]]; then
  cp "${APP_ICON_PATH}" "${RESOURCES_DIR}/AppIcon.icns"
  ICON_PLIST_LINES=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
fi

SPARKLE_PLIST_LINES=""
if [[ -n "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
  SPARKLE_PLIST_LINES=$'  <key>SUFeedURL</key>\n  <string>'"${SPARKLE_APPCAST_URL}"$'</string>\n'
  SPARKLE_PLIST_LINES+=$'  <key>SUPublicEDKey</key>\n  <string>'"${SPARKLE_PUBLIC_ED_KEY}"$'</string>\n'
  SPARKLE_PLIST_LINES+=$'  <key>SUEnableAutomaticChecks</key>\n  <true/>\n'
  SPARKLE_PLIST_LINES+=$'  <key>SUAutomaticallyUpdate</key>\n  <true/>\n'
  SPARKLE_PLIST_LINES+=$'  <key>SUScheduledCheckInterval</key>\n  <real>86400</real>'
else
  echo "Warning: SPARKLE_PUBLIC_ED_KEY is not set; packaged app will not be able to start Sparkle updates." >&2
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
${SPARKLE_PLIST_LINES}
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign "${CODE_SIGN_IDENTITY}" "${APP_DIR}" >/dev/null
codesign --verify --deep --strict "${APP_DIR}" >/dev/null

mkdir -p "${DIST_DIR}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Built app bundle: ${APP_DIR}"
echo "Built release archive: ${ZIP_PATH}"
