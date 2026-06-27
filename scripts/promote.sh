#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/promote.sh <version>

Example:
  bash scripts/promote.sh v1.1.0

Environment variables:
  STAGING_URL                Optional staging URL for smoke test.
  AUTO_DEPLOY_PRODUCTION     Set to true to call scripts/deploy.sh production.
USAGE
}

log() {
  printf '[promote] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: version must use semantic version format like v1.1.0." >&2
  exit 1
fi

log "Checking staging smoke test before promoting ${VERSION}"
if [[ -n "${STAGING_URL:-}" ]]; then
  bash "${SCRIPT_DIR}/smoke-test.sh" staging "${STAGING_URL}"
else
  bash "${SCRIPT_DIR}/smoke-test.sh" staging
fi

cat <<CHECKLIST

Production release checklist for ${VERSION}
- CI test passed
- Docker image exists and has Trivy scan result
- staging smoke test passed
- production version is explicit, not latest
- previous version is known for rollback
- production approver has reviewed the change

CHECKLIST

if [[ "${AUTO_DEPLOY_PRODUCTION:-false}" == "true" ]]; then
  log "AUTO_DEPLOY_PRODUCTION=true, deploying production overlay."
  bash "${SCRIPT_DIR}/deploy.sh" production
else
  log "Promotion is ready. Use GitHub Actions promote-production with environment approval for production."
fi
