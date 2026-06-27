#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/deploy.sh <dev|staging|production>

Examples:
  bash scripts/deploy.sh dev
  bash scripts/deploy.sh staging
  bash scripts/deploy.sh production
USAGE
}

log() {
  printf '[deploy] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

ENVIRONMENT="$1"
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
  echo "ERROR: kubectl command not found. Install kubectl or use CI render checks only." >&2
  exit 1
fi

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "ERROR: Kubernetes cluster is not reachable. Check kubeconfig and current context." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERLAY="${ROOT_DIR}/k8s/overlays/${ENVIRONMENT}"

log "Deploying ${ENVIRONMENT} to namespace ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k "${OVERLAY}"
kubectl -n "${NAMESPACE}" rollout status deployment/release-demo-service --timeout=180s

log "Deployment completed."
log "Port-forward example: kubectl -n ${NAMESPACE} port-forward svc/release-demo-service 8080:80"
log "Smoke test example: bash scripts/smoke-test.sh ${ENVIRONMENT} http://localhost:8080"
