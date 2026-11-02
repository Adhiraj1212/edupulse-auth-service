#!/usr/bin/env bash
# Push auth-service image to AWS ECR with immutable tags.
# Usage: ./scripts/ecr-push.sh [tag] [registry]
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need aws
need docker

TAG="${1:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo dev)}"
REGISTRY="${2:-$(ecr_registry)}"
REPO="${PROJECT}/${COMPONENT}"

log "Authenticating with Amazon ECR (${REGISTRY})..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY}" >/dev/null

if aws ecr describe-images --region "${AWS_REGION}" --repository-name "${REPO}" --image-ids "imageTag=${TAG}" >/dev/null 2>&1; then
  log "Image ${REPO}:${TAG} already exists in ECR (immutable) - skipping push."
  exit 0
fi

log "Tagging and pushing ${REGISTRY}/${REPO}:${TAG}..."
docker tag "${PROJECT}/${COMPONENT}:${TAG}" "${REGISTRY}/${REPO}:${TAG}"
docker push "${REGISTRY}/${REPO}:${TAG}"
log "Successfully pushed to ECR: ${REGISTRY}/${REPO}:${TAG}"

