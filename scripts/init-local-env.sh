#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/init-local-env.sh [--dry-run]

Reads .env and generates local, git-ignored configuration files:
  terraform/.envrc
  terraform/*/backend.hcl
  terraform/*/secrets.auto.tfvars
  terraform/*/terraform.tfvars

.env is the source of truth for user-provided values. OCI identity values
are read from ~/.oci/config when they are not explicitly set in .env.
USAGE
}

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
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

if [[ ! -f .env ]]; then
  echo "Missing .env" >&2
  echo "Create it from the example first:" >&2
  echo "  cp .env.example .env" >&2
  echo "  \$EDITOR .env" >&2
  exit 1
fi

# .env is a local, user-controlled shell-compatible file.
set -a
# shellcheck disable=SC1091
source .env
set +a

OCI_PROFILE="${OCI_PROFILE:-DEFAULT}"
OCI_CONFIG_FILE="${OCI_CONFIG_FILE:-$HOME/.oci/config}"

oci_config_value() {
  local key="$1"
  local profile="$2"
  local file="$3"

  [[ -f "$file" ]] || return 0

  awk -v section="$profile" -v key="$key" '
    $0 ~ /^\[/ {
      current=$0
      gsub(/^\[/, "", current)
      gsub(/\]$/, "", current)
      in_section=(current == section)
      next
    }
    in_section {
      line=$0
      sub(/#.*/, "", line)
      if (line ~ "^[[:space:]]*" key "[[:space:]]*=") {
        sub(/^[^=]*=[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

set_from_oci_config() {
  local var_name="$1"
  local config_key="$2"
  local current="${!var_name:-}"
  local value=""

  if [[ -z "$current" ]]; then
    value="$(oci_config_value "$config_key" "$OCI_PROFILE" "$OCI_CONFIG_FILE")"
    if [[ -n "$value" ]]; then
      printf -v "$var_name" '%s' "$value"
      export "$var_name"
    fi
  fi
}

set_from_oci_config OCI_TENANCY_OCID tenancy
set_from_oci_config OCI_USER_OCID user
set_from_oci_config OCI_FINGERPRINT fingerprint
set_from_oci_config OCI_PRIVATE_KEY_PATH key_file
set_from_oci_config OCI_REGION region

required_vars=(
  OCI_PROFILE
  OCI_REGION
  OCI_TENANCY_OCID
  OCI_COMPARTMENT_OCID
  OCI_USER_OCID
  OCI_FINGERPRINT
  OCI_PRIVATE_KEY_PATH
  TOFU_STATE_BUCKET
  TOFU_STATE_PREFIX
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  GITHUB_OWNER
  GITHUB_REPOSITORY
  GITHUB_BRANCH
  GITHUB_TOKEN
  BASE_DOMAIN
  LETSENCRYPT_EMAIL
  CLOUDFLARE_API_TOKEN
)

missing=0
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required .env or OCI config value: $var" >&2
    missing=$((missing + 1))
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo >&2
  echo "Tip: OCI_TENANCY_OCID, OCI_USER_OCID, OCI_FINGERPRINT, OCI_PRIVATE_KEY_PATH, and OCI_REGION" >&2
  echo "can be read from ~/.oci/config using OCI_PROFILE=$OCI_PROFILE." >&2
  exit 1
fi

if [[ -z "${OCI_OBJECT_STORAGE_NAMESPACE:-}" ]]; then
  if command -v oci >/dev/null 2>&1; then
    OCI_OBJECT_STORAGE_NAMESPACE="$(oci os ns get --profile "$OCI_PROFILE" --query data --raw-output 2>/dev/null || true)"
  fi
fi

if [[ -z "${OCI_OBJECT_STORAGE_NAMESPACE:-}" ]]; then
  echo "Could not read OCI Object Storage namespace with OCI CLI." >&2
  echo "Check OCI_PROFILE=$OCI_PROFILE or set OCI_OBJECT_STORAGE_NAMESPACE in .env." >&2
  exit 1
fi

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

PRIVATE_KEY_PATH="${OCI_PRIVATE_KEY_PATH/#\~/$HOME}"
STATE_ENDPOINT="https://${OCI_OBJECT_STORAGE_NAMESPACE}.compat.objectstorage.${OCI_REGION}.oraclecloud.com"

CLUSTER_NAME="${CLUSTER_NAME:-oke-cluster}"
NODE_POOL_NAME="${NODE_POOL_NAME:-pool1}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_OCPUS="${NODE_OCPUS:-1}"
NODE_MEMORY_GBS="${NODE_MEMORY_GBS:-8}"
NODE_BOOT_VOLUME_SIZE_GBS="${NODE_BOOT_VOLUME_SIZE_GBS:-66}"
API_ENDPOINT_ALLOWED_CIDRS="${API_ENDPOINT_ALLOWED_CIDRS:-[\"0.0.0.0/0\"]}"

DOMAIN_SLUG="$(slugify "$BASE_DOMAIN")"
CLUSTER_SLUG="$(slugify "$CLUSTER_NAME")"
EXTERNAL_DNS_TXT_OWNER_ID="${EXTERNAL_DNS_TXT_OWNER_ID:-${CLUSTER_SLUG}-external-dns}"
GATEWAY_TLS_SECRET_NAME="${GATEWAY_TLS_SECRET_NAME:-${DOMAIN_SLUG}-tls}"

VAULT_DISPLAY_NAME="${VAULT_DISPLAY_NAME:-${CLUSTER_SLUG}-vault}"
VAULT_KEY_DISPLAY_NAME="${VAULT_KEY_DISPLAY_NAME:-${CLUSTER_SLUG}-secrets-key}"
CLOUDFLARE_API_TOKEN_SECRET_NAME="${CLOUDFLARE_API_TOKEN_SECRET_NAME:-cloudflare-api-token}"

hcl_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_file() {
  local path="$1"
  local content="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would write $path"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  echo "wrote $path"
}

ensure_state_bucket() {
  if ! command -v oci >/dev/null 2>&1; then
    echo "Missing oci command; cannot check or create state bucket." >&2
    exit 1
  fi

  if oci os bucket get \
    --profile "$OCI_PROFILE" \
    --namespace-name "$OCI_OBJECT_STORAGE_NAMESPACE" \
    --name "$TOFU_STATE_BUCKET" >/dev/null 2>&1; then
    echo "ok: Object Storage bucket $TOFU_STATE_BUCKET exists"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would create Object Storage bucket $TOFU_STATE_BUCKET in compartment $OCI_COMPARTMENT_OCID"
    return 0
  fi

  echo "creating Object Storage bucket $TOFU_STATE_BUCKET"
  oci os bucket create \
    --profile "$OCI_PROFILE" \
    --namespace-name "$OCI_OBJECT_STORAGE_NAMESPACE" \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --name "$TOFU_STATE_BUCKET" \
    --public-access-type NoPublicAccess \
    --storage-tier Standard >/dev/null
}

write_backend() {
  local stack="$1"
  local key="$2"

  write_file "terraform/${stack}/backend.hcl" "bucket   = \"$(hcl_escape "$TOFU_STATE_BUCKET")\"
key      = \"$(hcl_escape "$key")\"
region   = \"$(hcl_escape "$OCI_REGION")\"
endpoint = \"$(hcl_escape "$STATE_ENDPOINT")\""
}

write_oci_secrets() {
  local stack="$1"
  local extra="${2:-}"

  write_file "terraform/${stack}/secrets.auto.tfvars" "tenancy_ocid     = \"$(hcl_escape "$OCI_TENANCY_OCID")\"
compartment_ocid = \"$(hcl_escape "$OCI_COMPARTMENT_OCID")\"
user_ocid        = \"$(hcl_escape "$OCI_USER_OCID")\"
fingerprint      = \"$(hcl_escape "$OCI_FINGERPRINT")\"
private_key_path = \"$(hcl_escape "$PRIVATE_KEY_PATH")\"
region           = \"$(hcl_escape "$OCI_REGION")\"${extra}"
}

ensure_state_bucket

write_file "terraform/.envrc" "export AWS_ACCESS_KEY_ID=\"$(hcl_escape "$AWS_ACCESS_KEY_ID")\"
export AWS_SECRET_ACCESS_KEY=\"$(hcl_escape "$AWS_SECRET_ACCESS_KEY")\"
export AWS_EC2_METADATA_DISABLED=true
export OCI_CLI_PROFILE=\"$(hcl_escape "$OCI_PROFILE")\"
export OCI_CLI_REGION=\"$(hcl_escape "$OCI_REGION")\"
export OCI_REGION=\"$(hcl_escape "$OCI_REGION")\""

write_backend foundation "${TOFU_STATE_PREFIX}/foundation.tfstate"
write_backend oci-oke "${TOFU_STATE_PREFIX}/terraform.tfstate"
write_backend flux "${TOFU_STATE_PREFIX}/flux.tfstate"

write_oci_secrets foundation "
cloudflare_api_token = \"$(hcl_escape "$CLOUDFLARE_API_TOKEN")\""
write_oci_secrets oci-oke
write_file "terraform/flux/secrets.auto.tfvars" "tenancy_ocid     = \"$(hcl_escape "$OCI_TENANCY_OCID")\"
user_ocid        = \"$(hcl_escape "$OCI_USER_OCID")\"
fingerprint      = \"$(hcl_escape "$OCI_FINGERPRINT")\"
private_key_path = \"$(hcl_escape "$PRIVATE_KEY_PATH")\"
region           = \"$(hcl_escape "$OCI_REGION")\"
github_token     = \"$(hcl_escape "$GITHUB_TOKEN")\""

write_file "terraform/foundation/terraform.tfvars" "vault_display_name                 = \"$(hcl_escape "$VAULT_DISPLAY_NAME")\"
vault_key_display_name             = \"$(hcl_escape "$VAULT_KEY_DISPLAY_NAME")\"
cloudflare_api_token_secret_name   = \"$(hcl_escape "$CLOUDFLARE_API_TOKEN_SECRET_NAME")\"
vault_store_cloudflare_api_token   = true"

write_file "terraform/oci-oke/terraform.tfvars" "cluster_name                  = \"$(hcl_escape "$CLUSTER_NAME")\"
node_pool_name                = \"$(hcl_escape "$NODE_POOL_NAME")\"
node_count                    = ${NODE_COUNT}
node_ocpus                    = ${NODE_OCPUS}
node_memory_gbs               = ${NODE_MEMORY_GBS}
node_boot_volume_size_gbs     = ${NODE_BOOT_VOLUME_SIZE_GBS}
api_endpoint_allowed_cidrs    = ${API_ENDPOINT_ALLOWED_CIDRS}"

write_file "terraform/flux/terraform.tfvars" "github_owner      = \"$(hcl_escape "$GITHUB_OWNER")\"
github_repository = \"$(hcl_escape "$GITHUB_REPOSITORY")\"
github_branch     = \"$(hcl_escape "$GITHUB_BRANCH")\"
flux_gitops_path  = \"gitops/clusters/oke_cluster\"

base_domain               = \"$(hcl_escape "$BASE_DOMAIN")\"
letsencrypt_email         = \"$(hcl_escape "$LETSENCRYPT_EMAIL")\"
external_dns_txt_owner_id = \"$(hcl_escape "$EXTERNAL_DNS_TXT_OWNER_ID")\"
gateway_tls_secret_name   = \"$(hcl_escape "$GATEWAY_TLS_SECRET_NAME")\"

oci_oke_state_bucket   = \"$(hcl_escape "$TOFU_STATE_BUCKET")\"
oci_oke_state_key      = \"$(hcl_escape "${TOFU_STATE_PREFIX}/terraform.tfstate")\"
oci_oke_state_region   = \"$(hcl_escape "$OCI_REGION")\"
oci_oke_state_endpoint = \"$(hcl_escape "$STATE_ENDPOINT")\"

foundation_state_bucket   = \"$(hcl_escape "$TOFU_STATE_BUCKET")\"
foundation_state_key      = \"$(hcl_escape "${TOFU_STATE_PREFIX}/foundation.tfstate")\"
foundation_state_region   = \"$(hcl_escape "$OCI_REGION")\"
foundation_state_endpoint = \"$(hcl_escape "$STATE_ENDPOINT")\""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "Dry run complete. No files were changed."
else
  echo
  echo "Local configuration generated from .env."
  echo "Generated files are local-only and must remain ignored by Git."
fi
