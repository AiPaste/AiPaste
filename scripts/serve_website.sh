#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/serve_website.sh [port]

Examples:
  ./scripts/serve_website.sh
  ./scripts/serve_website.sh 4173

Environment variables:
  HOST   Bind host, default: 127.0.0.1
  PORT   Bind port, default: 4000
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS_DIR="${ROOT_DIR}/docs"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-${1:-4000}}"

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "Missing docs directory: ${DOCS_DIR}" >&2
  exit 1
fi

if ! [[ "${PORT}" =~ ^[0-9]+$ ]]; then
  echo "Port must be a number: ${PORT}" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Python is required to serve the website locally." >&2
  exit 1
fi

echo "Serving ${DOCS_DIR} at http://${HOST}:${PORT}"
cd "${DOCS_DIR}"
exec "${PYTHON_BIN}" -m http.server "${PORT}" --bind "${HOST}"
