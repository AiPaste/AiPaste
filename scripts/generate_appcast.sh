#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCHIVES_DIR="${1:-${ARCHIVES_DIR:-${ROOT_DIR}/dist}}"
OUTPUT_PATH="${2:-${OUTPUT_PATH:-${ARCHIVES_DIR}/appcast.xml}}"
SPARKLE_CHECKOUT_DIR="${ROOT_DIR}/.build/checkouts/Sparkle"
DERIVED_DATA_DIR="${ROOT_DIR}/.build/sparkle-tools"
PROJECT_PATH="${SPARKLE_CHECKOUT_DIR}/Sparkle.xcodeproj"
TOOL_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/generate_appcast"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-}"
RELEASE_LINK="${SPARKLE_RELEASE_LINK:-}"
PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/generate_appcast.sh [archives_dir] [output_path]

Environment:
  SPARKLE_PRIVATE_KEY         Required. Base64-encoded Sparkle EdDSA private key secret.
  SPARKLE_DOWNLOAD_URL_PREFIX Required. Prefix used for enclosure URLs in the generated appcast.
  SPARKLE_RELEASE_LINK        Optional. Link shown by Sparkle for the release item.

Examples:
  SPARKLE_PRIVATE_KEY=... \
  SPARKLE_DOWNLOAD_URL_PREFIX=https://github.com/AiPaste/AiPaste/releases/download/v0.1.0/ \
  SPARKLE_RELEASE_LINK=https://github.com/AiPaste/AiPaste/releases/tag/v0.1.0 \
  ./scripts/generate_appcast.sh dist docs/appcast.xml
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

GENERATE_ARGS=(
  --ed-key-file -
  --download-url-prefix "${DOWNLOAD_URL_PREFIX}"
  -o "${OUTPUT_PATH}"
)

if [[ -n "${RELEASE_LINK}" ]]; then
  GENERATE_ARGS+=(--link "${RELEASE_LINK}")
fi

printf '%s' "${PRIVATE_KEY}" | "${TOOL_PATH}" "${GENERATE_ARGS[@]}" "${ARCHIVES_DIR}"

echo "Generated appcast: ${OUTPUT_PATH}"
