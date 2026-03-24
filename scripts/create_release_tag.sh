#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/create_release_tag.sh <tag> [--push] [--yes] [--preview]

Examples:
  ./scripts/create_release_tag.sh v0.1.4
  ./scripts/create_release_tag.sh v0.1.4 --push
  ./scripts/create_release_tag.sh v0.1.4 --preview

Behavior:
  - Creates an annotated git tag
  - Tag message includes:
    1. Current changes: previous tag -> HEAD
    2. Previous release changes: tag before previous -> previous tag
  - Opens $EDITOR for review by default
  - Use --yes to skip editing and create the tag immediately
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

TAG_NAME=""
PUSH_TAG=false
SKIP_EDIT=false
PREVIEW_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      PUSH_TAG=true
      shift
      ;;
    --yes)
      SKIP_EDIT=true
      shift
      ;;
    --preview)
      PREVIEW_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "${TAG_NAME}" ]]; then
        TAG_NAME="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "${TAG_NAME}" ]]; then
  echo "Missing tag name." >&2
  usage
  exit 1
fi

if git rev-parse --verify --quiet "refs/tags/${TAG_NAME}" >/dev/null; then
  echo "Tag already exists: ${TAG_NAME}" >&2
  exit 1
fi

LATEST_TAG="$(git tag --sort=-version:refname | head -n 1 || true)"
PREVIOUS_TAG=""
if [[ -n "${LATEST_TAG}" ]]; then
  PREVIOUS_TAG="$(git tag --sort=-version:refname | sed -n '2p' || true)"
fi

if [[ -n "${LATEST_TAG}" ]]; then
  CURRENT_RANGE="${LATEST_TAG}..HEAD"
  CURRENT_CHANGES="$(git log --reverse --pretty='- %s' "${CURRENT_RANGE}")"
else
  CURRENT_RANGE="initial..HEAD"
  CURRENT_CHANGES="$(git log --reverse --pretty='- %s')"
fi

if [[ -z "${CURRENT_CHANGES}" ]]; then
  echo "No new commits found since ${LATEST_TAG:-repository start}. Refusing to create an empty release tag." >&2
  exit 1
fi

if [[ -n "${LATEST_TAG}" && -n "${PREVIOUS_TAG}" ]]; then
  PREVIOUS_RANGE="${PREVIOUS_TAG}..${LATEST_TAG}"
  PREVIOUS_CHANGES="$(git log --reverse --pretty='- %s' "${PREVIOUS_RANGE}")"
elif [[ -n "${LATEST_TAG}" ]]; then
  PREVIOUS_RANGE="initial..${LATEST_TAG}"
  PREVIOUS_CHANGES="$(git log --reverse --pretty='- %s' "${LATEST_TAG}")"
else
  PREVIOUS_RANGE="none"
  PREVIOUS_CHANGES="- No previous tagged release."
fi

MESSAGE_FILE="$(mktemp)"
trap 'rm -f "${MESSAGE_FILE}"' EXIT

cat > "${MESSAGE_FILE}" <<EOF
Release ${TAG_NAME}

Current changes (${CURRENT_RANGE}):
${CURRENT_CHANGES}

Previous release changes (${PREVIOUS_RANGE}):
${PREVIOUS_CHANGES}
EOF

if [[ "${SKIP_EDIT}" != true ]]; then
  "${EDITOR:-vi}" "${MESSAGE_FILE}"
fi

if [[ "${PREVIEW_ONLY}" == true ]]; then
  cat "${MESSAGE_FILE}"
  exit 0
fi

git tag -a "${TAG_NAME}" -F "${MESSAGE_FILE}"
echo "Created annotated tag ${TAG_NAME}"

if [[ "${PUSH_TAG}" == true ]]; then
  git push origin "${TAG_NAME}"
  echo "Pushed tag ${TAG_NAME} to origin"
fi
