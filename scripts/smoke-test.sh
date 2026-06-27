#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/smoke-test.sh <dev|staging|production> [base_url] [service_name]

Examples:
  bash scripts/smoke-test.sh staging http://localhost:8080
  bash scripts/smoke-test.sh staging
  bash scripts/smoke-test.sh production "" release-demo-service-canary
USAGE
}

log() {
  printf '[smoke-test] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage
  exit 1
fi

ENVIRONMENT="$1"
BASE_URL="${2:-}"
SERVICE_NAME="${3:-release-demo-service}"

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

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl command not found." >&2
  exit 1
fi

PORT_FORWARD_PID=""
cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -z "${BASE_URL}" ]]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl command not found and no base_url was provided." >&2
    exit 1
  fi
  if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
    echo "ERROR: Kubernetes cluster is not reachable and no base_url was provided." >&2
    exit 1
  fi

  LOCAL_PORT="${SMOKE_TEST_PORT:-18080}"
  BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
  log "Starting port-forward svc/${SERVICE_NAME} ${LOCAL_PORT}:80 in namespace ${NAMESPACE}"
  kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE_NAME}" "${LOCAL_PORT}:80" >/tmp/release-demo-port-forward.log 2>&1 &
  PORT_FORWARD_PID="$!"
  sleep 3

  if ! kill -0 "${PORT_FORWARD_PID}" >/dev/null 2>&1; then
    echo "ERROR: port-forward failed. See /tmp/release-demo-port-forward.log." >&2
    exit 1
  fi
fi

check_endpoint() {
  local path="$1"
  local url="${BASE_URL}${path}"
  log "Checking ${url}"
  curl --fail --show-error --silent --max-time 10 "${url}" >/tmp/release-demo-smoke-response.json
  log "PASS ${path}"
}

check_endpoint "/healthz"
check_endpoint "/readyz"
check_endpoint "/version"
check_endpoint "/api/order"

log "Smoke test completed for ${ENVIRONMENT} via ${BASE_URL}"
