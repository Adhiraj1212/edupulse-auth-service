#!/usr/bin/env bash
# Developer + CI entry point for edupulse-auth-service.
# Run locally to mirror the exact checks performed in GitHub Actions.
# Usage: ./scripts/ci.sh <task>
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$(repo_root)"

TAG="${TAG:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo dev)}"
REGISTRY="${REGISTRY:-}"
REPORTS="${REPORTS:-reports}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IMG="${PROJECT}/${COMPONENT}:${TAG}"

mkdir -p "${REPORTS}"

task_gitleaks() {
  log "==> Running Gitleaks secret scan..."
  if has gitleaks; then
    gitleaks detect --source . --config .gitleaks.toml --redact --no-banner --verbose
  else
    need docker
    docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect --source /repo --config /repo/.gitleaks.toml --redact --no-banner --verbose
  fi
}

task_audit() {
  log "==> Running npm audit (SCA dependency vulnerability scan)..."
  need npm
  npm audit --omit=dev --audit-level=high
}

task_syntax() {
  log "==> Running Node.js syntax checks..."
  need node
  find . -name '*.js' -not -path './node_modules/*' -print0 | xargs -0 -n1 node --check
  log "All JavaScript files passed syntax verification."
}

task_hadolint() {
  log "==> Running Hadolint Dockerfile linting..."
  if has hadolint; then
    hadolint --config .hadolint.yaml Dockerfile
  else
    need docker
    docker run --rm -i hadolint/hadolint:latest < Dockerfile
  fi
}

task_build() {
  log "==> Building Docker image: ${IMG}..."
  need docker
  docker build -t "${IMG}" .
}

task_image_scan() {
  log "==> Scanning container image with Trivy (severity: ${SEVERITY})..."
  need docker
  if has trivy; then
    trivy image --severity "${SEVERITY}" --ignore-unfixed --exit-code 1 "${IMG}"
  else
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      aquasec/trivy:0.58.2 image --severity "${SEVERITY}" --ignore-unfixed --exit-code 1 "${IMG}"
  fi
}

task_sbom() {
  log "==> Generating CycloneDX SBOM..."
  need docker
  if has trivy; then
    trivy image --format cyclonedx --output "${REPORTS}/sbom-${COMPONENT}.cdx.json" "${IMG}"
  else
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${REPORTS}:/out" \
      aquasec/trivy:0.58.2 image --format cyclonedx --output "/out/sbom-${COMPONENT}.cdx.json" "${IMG}"
  fi
  log "SBOM written to ${REPORTS}/sbom-${COMPONENT}.cdx.json"
}

task_all() {
  task_gitleaks
  task_syntax
  task_audit
  task_hadolint
  task_build
  task_image_scan
  task_sbom
  log "All DevSecOps checks PASSED for ${COMPONENT}!"
}

task_local_up() {
  need docker
  docker compose up --build -d
  log "Auth Service running at http://localhost:4000"
}

task_local_down() {
  need docker
  docker compose down -v
}

task_clean() {
  rm -rf "${REPORTS}"
}

usage() {
  cat <<'USAGE'
Usage: ./scripts/ci.sh <command>

DevSecOps tasks:
  gitleaks     Secret scan with Gitleaks
  audit        npm dependency vulnerability scan (SCA)
  syntax       Node.js syntax check (SAST)
  hadolint     Lint Dockerfile
  build        Build container image
  image-scan   Scan built image for CVEs using Trivy (fails on HIGH/CRITICAL)
  sbom         Generate CycloneDX SBOM report
  all          Run complete security pipeline locally

Local dev tasks:
  local-up     Start auth-service with docker compose
  local-down   Stop local container
  clean        Clean up reports/
USAGE
}

cmd="${1:-help}"
shift || true
case "${cmd}" in
  help|-h|--help) usage ;;
  gitleaks|audit|syntax|hadolint|build|image-scan|sbom|all|local-up|local-down|clean)
    "task_${cmd//-/_}" "$@" ;;
  *) usage >&2; die "unknown command: ${cmd}" ;;
esac

