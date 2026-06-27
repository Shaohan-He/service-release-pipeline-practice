#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/rollback.sh <dev|staging|production> --undo
  bash scripts/rollback.sh <dev|staging|production> <image_tag>

Examples:
  bash scripts/rollback.sh production --undo
  bash scripts/rollback.sh production v1.0.0
USAGE
}

log() {
  printf '[rollback] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

ENVIRONMENT="$1"
TARGET="$2"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/shaohan-he/release-demo-service}"

case "${ENVIRONMENT}" in
  dev) NAMESPACE="service-dev" ;;
  staging) NAMESPACE="service-staging" ;;
  production) NAMESPACE="service-production" ;;
  *)
    echo "ERROR: environment must be one of: dev, staging, production." >&2
    usage
    exit 1
    ;;
esac

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl command not found." >&2
  exit 1
fi

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "ERROR: Kubernetes cluster is not reachable. Check kubeconfig and current context." >&2
  exit 1
fi

if [[ "${TARGET}" == "--undo" ]]; then
  log "Running native rollout undo for ${ENVIRONMENT}"
  kubectl -n "${NAMESPACE}" rollout undo deployment/release-demo-service
else
  log "Rolling back ${ENVIRONMENT} to image tag ${TARGET}"
  kubectl -n "${NAMESPACE}" set image deployment/release-demo-service "app=${IMAGE_NAME}:${TARGET}"
  kubectl -n "${NAMESPACE}" set env deployment/release-demo-service "IMAGE_TAG=${TARGET}" "APP_VERSION=${TARGET}"
fi

kubectl -n "${NAMESPACE}" rollout status deployment/release-demo-service --timeout=180s
log "Rollback completed. Run: bash scripts/smoke-test.sh ${ENVIRONMENT}"
