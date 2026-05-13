#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/preflight.sh

Checks local prerequisites and ignored configuration files.
Use `just validate` to run this check together with OpenTofu init and plan.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

failures=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "ok: command $cmd"
  else
    echo "missing: command $cmd" >&2
    failures=$((failures + 1))
  fi
}

check_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "ok: file $file"
  else
    echo "missing: file $file" >&2
    failures=$((failures + 1))
  fi
}

check_not_tracked() {
  local file="$1"
  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    echo "tracked but should be local only: $file" >&2
    failures=$((failures + 1))
  else
    echo "ok: not tracked $file"
  fi
}

for cmd in git oci tofu just direnv kubectl flux; do
  check_cmd "$cmd"
done

check_file ".env"
check_not_tracked ".env"

for stack in foundation oci-oke flux; do
  check_file "terraform/${stack}/backend.hcl"
  check_file "terraform/${stack}/secrets.auto.tfvars"
  check_file "terraform/${stack}/terraform.tfvars"
  check_not_tracked "terraform/${stack}/backend.hcl"
  check_not_tracked "terraform/${stack}/secrets.auto.tfvars"
  check_not_tracked "terraform/${stack}/terraform.tfvars"
done

check_file "terraform/.envrc"
check_not_tracked "terraform/.envrc"

if command -v oci >/dev/null 2>&1; then
  namespace="$(oci os ns get --profile "${OCI_PROFILE:-DEFAULT}" --query data --raw-output 2>/dev/null || true)"
  if [[ -n "$namespace" ]]; then
    echo "ok: OCI CLI can read Object Storage namespace"
    if [[ -n "${TOFU_STATE_BUCKET:-}" ]]; then
      if oci os bucket get --profile "${OCI_PROFILE:-DEFAULT}" --namespace-name "$namespace" --name "$TOFU_STATE_BUCKET" >/dev/null 2>&1; then
        echo "ok: Object Storage state bucket exists"
      else
        echo "missing: Object Storage state bucket $TOFU_STATE_BUCKET" >&2
        failures=$((failures + 1))
      fi
    fi
  else
    echo "warning: OCI CLI could not read Object Storage namespace with profile ${OCI_PROFILE:-DEFAULT}" >&2
  fi
fi

if [[ "$failures" -ne 0 ]]; then
  echo
  echo "Validation failed with $failures issue(s)." >&2
  exit 1
fi

echo
echo "Local validation checks passed."
