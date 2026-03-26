#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCHIVES_DIR="${1:-${ARCHIVES_DIR:-${ROOT_DIR}/dist}}"
OUTPUT_PATH="${2:-${OUTPUT_PATH:-${ARCHIVES_DIR}/appcast.xml}}"
EXISTING_APPCAST_PATH="${EXISTING_APPCAST_PATH:-}"
ARCHIVE_FILE_PATH="${ARCHIVE_FILE_PATH:-}"
SPARKLE_CHECKOUT_DIR="${ROOT_DIR}/.build/checkouts/Sparkle"
DERIVED_DATA_DIR="${ROOT_DIR}/.build/sparkle-tools"
PROJECT_PATH="${SPARKLE_CHECKOUT_DIR}/Sparkle.xcodeproj"
TOOL_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/generate_appcast"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-}"
RELEASE_LINK="${SPARKLE_RELEASE_LINK:-}"
PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"
WORK_DIR="${ARCHIVES_DIR}"
TEMP_STAGE_DIR=""

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/generate_appcast.sh [archives_dir] [output_path]

Environment:
  SPARKLE_PRIVATE_KEY         Required. Base64-encoded Sparkle EdDSA private key secret.
  SPARKLE_DOWNLOAD_URL_PREFIX Required. Prefix used for enclosure URLs in the generated appcast.
  SPARKLE_RELEASE_LINK        Optional. Link shown by Sparkle for the release item.
  ARCHIVE_FILE_PATH           Optional. If set, generate the appcast from only this archive.
  EXISTING_APPCAST_PATH       Optional. Existing appcast.xml to seed into the staging directory.

Examples:
  SPARKLE_PRIVATE_KEY=... \
  SPARKLE_DOWNLOAD_URL_PREFIX=https://github.com/AiPaste/AiPaste/releases/download/v0.1.0/ \
  SPARKLE_RELEASE_LINK=https://github.com/AiPaste/AiPaste/releases/tag/v0.1.0 \
  ./scripts/generate_appcast.sh dist docs/appcast.xml

  ARCHIVE_FILE_PATH=dist/AiPaste-0.1.0-macOS.zip \
  EXISTING_APPCAST_PATH=docs/appcast.xml \
  SPARKLE_PRIVATE_KEY=... \
  SPARKLE_DOWNLOAD_URL_PREFIX=https://github.com/AiPaste/AiPaste/releases/download/v0.1.0/ \
  ./scripts/generate_appcast.sh dist dist/appcast.xml
EOF
  exit 0
fi

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "Missing SPARKLE_PRIVATE_KEY." >&2
  exit 1
fi

if [[ -z "${DOWNLOAD_URL_PREFIX}" ]]; then
  echo "Missing SPARKLE_DOWNLOAD_URL_PREFIX." >&2
  exit 1
fi

if [[ ! -d "${ARCHIVES_DIR}" ]]; then
  echo "Missing archives directory at ${ARCHIVES_DIR}" >&2
  exit 1
fi

if [[ -n "${ARCHIVE_FILE_PATH}" && ! -f "${ARCHIVE_FILE_PATH}" ]]; then
  echo "Missing archive file at ${ARCHIVE_FILE_PATH}" >&2
  exit 1
fi

if [[ -n "${EXISTING_APPCAST_PATH}" && ! -f "${EXISTING_APPCAST_PATH}" ]]; then
  echo "Missing existing appcast at ${EXISTING_APPCAST_PATH}" >&2
  exit 1
fi

if [[ ! -d "${SPARKLE_CHECKOUT_DIR}" ]]; then
  echo "Sparkle checkout not found at ${SPARKLE_CHECKOUT_DIR}. Run swift package resolve first." >&2
  exit 1
fi

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme generate_appcast \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  build >/dev/null

if [[ ! -x "${TOOL_PATH}" ]]; then
  echo "Missing generate_appcast tool at ${TOOL_PATH}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"

cleanup() {
  if [[ -n "${TEMP_STAGE_DIR}" && -d "${TEMP_STAGE_DIR}" ]]; then
    rm -rf "${TEMP_STAGE_DIR}"
  fi
}

trap cleanup EXIT

if [[ -n "${ARCHIVE_FILE_PATH}" ]]; then
  TEMP_STAGE_DIR="$(mktemp -d)"
  cp "${ARCHIVE_FILE_PATH}" "${TEMP_STAGE_DIR}/"
  if [[ -n "${EXISTING_APPCAST_PATH}" ]]; then
    cp "${EXISTING_APPCAST_PATH}" "${TEMP_STAGE_DIR}/appcast.xml"
  fi
  WORK_DIR="${TEMP_STAGE_DIR}"
fi

GENERATE_ARGS=(
  --ed-key-file -
  --download-url-prefix "${DOWNLOAD_URL_PREFIX}"
  -o "${OUTPUT_PATH}"
)

if [[ -n "${RELEASE_LINK}" ]]; then
  GENERATE_ARGS+=(--link "${RELEASE_LINK}")
fi

printf '%s' "${PRIVATE_KEY}" | "${TOOL_PATH}" "${GENERATE_ARGS[@]}" "${WORK_DIR}"

echo "Generated appcast: ${OUTPUT_PATH}"
