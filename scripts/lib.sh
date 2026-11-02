#!/usr/bin/env bash
# Shared helpers for edupulse-auth-service scripts.
# shellcheck shell=bash
set -euo pipefail

export AWS_REGION="${AWS_REGION:-eu-north-1}"
export AWS_DEFAULT_REGION="${AWS_REGION}"
PROJECT="${PROJECT:-edupulse}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
COMPONENT="auth-service"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }
need() { has "$1" || die "required tool not found: $1"; }
repo_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }
aws_account_id() { aws sts get-caller-identity --query Account --output text; }
ecr_registry() { printf '%s.dkr.ecr.%s.amazonaws.com' "$(aws_account_id)" "${AWS_REGION}"; }

