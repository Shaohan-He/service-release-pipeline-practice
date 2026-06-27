#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/build-image.sh <image_name> <tag> [git_sha] [app_version]

Example:
  bash scripts/build-image.sh ghcr.io/shaohan-he/release-demo-service v1.0.0
  bash scripts/build-image.sh ghcr.io/shaohan-he/release-demo-service v1.1.0 abcdef1 v1.1.0
USAGE
}

log() {
  printf '[build-image] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker command not found. Install Docker Desktop or Docker Engine first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE_NAME="$1"
TAG="$2"
GIT_SHA="${3:-$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || true)}"
APP_VERSION="${4:-${TAG}}"
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ -z "${IMAGE_NAME}" || -z "${TAG}" ]]; then
  echo "ERROR: image_name and tag are required." >&2
  usage
  exit 1
fi

if [[ -z "${GIT_SHA}" ]]; then
  GIT_SHA="unknown"
fi

log "Image: ${IMAGE_NAME}:${TAG}"
log "Git SHA: ${GIT_SHA}"
log "App version: ${APP_VERSION}"
log "Build time: ${BUILD_TIME}"

set -x
docker build \
  --build-arg APP_VERSION="${APP_VERSION}" \
  --build-arg GIT_SHA="${GIT_SHA}" \
  --build-arg IMAGE_TAG="${TAG}" \
  --build-arg APP_ENV="${APP_ENV:-dev}" \
  --build-arg BUILD_TIME="${BUILD_TIME}" \
  -t "${IMAGE_NAME}:${TAG}" \
  "${ROOT_DIR}/app"
set +x

log "Build completed: ${IMAGE_NAME}:${TAG}"
