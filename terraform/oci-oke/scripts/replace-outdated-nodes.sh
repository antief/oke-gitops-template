#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

NODE_POOL_ID="${NODE_POOL_ID:-}"
TARGET_K8S_VERSION="${TARGET_K8S_VERSION:-}"
TARGET_IMAGE_ID="${TARGET_IMAGE_ID:-}"
GRACE_DURATION="${GRACE_DURATION:-PT30M}"
WAIT_SECONDS="${WAIT_SECONDS:-3600}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-30}"
LONGHORN_WAIT_SECONDS="${LONGHORN_WAIT_SECONDS:-2700}"
LONGHORN_WAIT_INTERVAL_SECONDS="${LONGHORN_WAIT_INTERVAL_SECONDS:-10}"
MAX_REPLACEMENTS="${MAX_REPLACEMENTS:-1}"
STATE_DIR="${STATE_DIR:-.oke-node-replace}"
DRY_RUN=false
FORCE=false
NO_TERRAFORM_OUTPUTS=false
SKIP_IMAGE_CHECK=false
AUTO_CLEAN_LONGHORN_STALE=true

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/replace-outdated-nodes.sh [options]

Replaces OKE managed nodes safely, one at a time, using:
  oci ce node-pool delete-node --is-decrement-size false

The script is intentionally conservative. By default it replaces at most one
node per run. Use --max-replacements to increase that limit explicitly.

By default the script reads these from OpenTofu/Terraform outputs in the
current directory:
  - node_pool_id
  - kubernetes_version
  - node_image_id

Options:
  --node-pool-id <ocid>             OKE node pool OCID
  --target-k8s-version <ver>        Target Kubernetes version, for example v1.35.2 or 1.35.2
  --target-image-id <ocid>          Target node image OCID. If the node pool API does not expose
                                    per-node image IDs, the script reads them from Compute instances.
  --skip-image-check                Ignore node image differences. Useful with restricted OCI policies.
  --force                           Treat ACTIVE nodes as candidates, even if they look current
  --max-replacements <n|all>        Maximum number of nodes to replace in this run. Default: 1
  --dry-run                         Print checks and selected candidates, but do not delete or clean anything
  --grace-duration <iso8601>        OKE eviction grace duration. Default: PT30M
  --wait-seconds <seconds>          Max wait for each OCI work request and Kubernetes readiness. Default: 3600
  --longhorn-wait-seconds <seconds> Max wait for Longhorn health after each replacement. Default: 2700
  --longhorn-wait-interval <sec>    Longhorn polling interval. Default: 10
  --no-longhorn-cleanup             Do not clean stale Longhorn replicas/nodes left by replaced nodes
  --no-terraform-outputs            Do not read tofu/terraform outputs automatically
  -h, --help                        Show this help

Environment variables with the same names are also supported:
  NODE_POOL_ID, TARGET_K8S_VERSION, TARGET_IMAGE_ID, GRACE_DURATION,
  WAIT_SECONDS, WAIT_INTERVAL_SECONDS, LONGHORN_WAIT_SECONDS,
  LONGHORN_WAIT_INTERVAL_SECONDS, MAX_REPLACEMENTS, STATE_DIR,
  AUTO_CLEAN_LONGHORN_STALE

Examples:
  tofu apply
  ./scripts/replace-outdated-nodes.sh --dry-run
  ./scripts/replace-outdated-nodes.sh

  # Deliberate one-node HA test
  ./scripts/replace-outdated-nodes.sh --force --max-replacements 1

  # Replace all matching candidates explicitly
  ./scripts/replace-outdated-nodes.sh --max-replacements all
USAGE
}

log()  { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '\n[%s] WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { printf '\n[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node-pool-id) NODE_POOL_ID="${2:-}"; shift 2 ;;
    --target-k8s-version) TARGET_K8S_VERSION="${2:-}"; shift 2 ;;
    --target-image-id) TARGET_IMAGE_ID="${2:-}"; shift 2 ;;
    --grace-duration) GRACE_DURATION="${2:-}"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="${2:-}"; shift 2 ;;
    --longhorn-wait-seconds) LONGHORN_WAIT_SECONDS="${2:-}"; shift 2 ;;
    --longhorn-wait-interval) LONGHORN_WAIT_INTERVAL_SECONDS="${2:-}"; shift 2 ;;
    --max-replacements) MAX_REPLACEMENTS="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --skip-image-check) SKIP_IMAGE_CHECK=true; shift ;;
    --no-longhorn-cleanup) AUTO_CLEAN_LONGHORN_STALE=false; shift ;;
    --no-terraform-outputs) NO_TERRAFORM_OUTPUTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
require_cmd oci
require_cmd kubectl
require_cmd jq
require_cmd flock

[[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || die "--wait-seconds must be an integer"
[[ "$WAIT_INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || die "WAIT_INTERVAL_SECONDS must be an integer"
[[ "$WAIT_INTERVAL_SECONDS" -gt 0 ]] || die "WAIT_INTERVAL_SECONDS must be greater than zero"
[[ "$LONGHORN_WAIT_SECONDS" =~ ^[0-9]+$ ]] || die "--longhorn-wait-seconds must be an integer"
[[ "$LONGHORN_WAIT_INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || die "--longhorn-wait-interval must be an integer"
[[ "$LONGHORN_WAIT_INTERVAL_SECONDS" -gt 0 ]] || die "--longhorn-wait-interval must be greater than zero"
if [[ "$MAX_REPLACEMENTS" != "all" ]]; then
  [[ "$MAX_REPLACEMENTS" =~ ^[0-9]+$ ]] || die "--max-replacements must be a positive integer or 'all'"
  [[ "$MAX_REPLACEMENTS" -gt 0 ]] || die "--max-replacements must be greater than zero"
fi

read_tf_output() {
  local name="$1"
  if command -v tofu >/dev/null 2>&1 && tofu output -raw "$name" >/dev/null 2>&1; then
    tofu output -raw "$name"
    return 0
  fi
  if command -v terraform >/dev/null 2>&1 && terraform output -raw "$name" >/dev/null 2>&1; then
    terraform output -raw "$name"
    return 0
  fi
  return 1
}

if [[ "$NO_TERRAFORM_OUTPUTS" == false ]]; then
  [[ -n "$NODE_POOL_ID" ]] || NODE_POOL_ID="$(read_tf_output node_pool_id || true)"
  [[ -n "$TARGET_K8S_VERSION" ]] || TARGET_K8S_VERSION="$(read_tf_output kubernetes_version || true)"
  [[ -n "$TARGET_IMAGE_ID" ]] || TARGET_IMAGE_ID="$(read_tf_output node_image_id || true)"
fi

[[ -n "$NODE_POOL_ID" ]] || die "NODE_POOL_ID is required. Run from terraform/oci-oke or pass --node-pool-id."

if [[ "$SKIP_IMAGE_CHECK" == true ]]; then
  TARGET_IMAGE_ID=""
fi

normalize_version() {
  local v="${1:-}"
  v="${v#v}"
  printf '%s' "$v"
}

TARGET_K8S_VERSION_NORM="$(normalize_version "$TARGET_K8S_VERSION")"

mkdir -p "$STATE_DIR"
LOCK_FILE="$STATE_DIR/lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  die "Another node replacement run appears to be active: $LOCK_FILE"
fi

node_pool_json() {
  oci ce node-pool get --node-pool-id "$NODE_POOL_ID" --output json
}

kubectl_nodes_json() {
  kubectl get nodes -o json
}

pool_lifecycle_state() {
  jq -r '.data."lifecycle-state" // .data.lifecycleState // "UNKNOWN"'
}

desired_size() {
  jq -r '.data."node-config-details".size // .data.nodeConfigDetails.size // (.data.nodes | length)'
}

active_node_count() {
  jq -r '[.data.nodes[]? | select((."lifecycle-state" // .lifecycleState // "") == "ACTIVE")] | length'
}

active_node_ids() {
  jq -r '.data.nodes[]? | select((."lifecycle-state" // .lifecycleState // "") == "ACTIVE") | .id'
}

kubectl_node_count_from_json() {
  local nodes_json="$1"
  printf '%s' "$nodes_json" | jq -r '.items | length'
}

ready_node_count_from_json() {
  local nodes_json="$1"
  printf '%s' "$nodes_json" | jq -r '
    [
      .items[]
      | select(.status.conditions[]? | select(.type == "Ready" and .status == "True"))
    ] | length
  '
}

k8s_name_for_oci_node_from_json() {
  local nodes_json="$1"
  local node_id="$2"
  printf '%s' "$nodes_json" | jq -r --arg id "$node_id" '
    .items[]
    | select(((.spec.providerID // "") == ("oci://" + $id)) or ((.spec.providerID // "") | endswith($id)))
    | .metadata.name
  ' | head -n1
}

k8s_node_ready_from_json() {
  local nodes_json="$1"
  local name="$2"
  [[ -n "$name" ]] || return 1
  printf '%s' "$nodes_json" | jq -e --arg name "$name" '
    .items[]
    | select(.metadata.name == $name)
    | .status.conditions[]?
    | select(.type == "Ready" and .status == "True")
  ' >/dev/null
}

k8s_node_exists_from_json() {
  local nodes_json="$1"
  local name="$2"
  printf '%s' "$nodes_json" | jq -e --arg name "$name" '.items[]? | select(.metadata.name == $name)' >/dev/null
}

k8s_node_version() {
  local name="$1"
  kubectl get node "$name" -o json 2>/dev/null | jq -r '.status.nodeInfo.kubeletVersion // ""'
}

compute_image_id_for_instance() {
  local instance_id="$1"
  oci compute instance get --instance-id "$instance_id" --output json 2>/dev/null \
    | jq -r '.data."image-id" // .data.imageId // ""'
}

image_id_for_node() {
  local node_json="$1"
  local node_id image_id
  node_id="$(printf '%s' "$node_json" | jq -r '.id')"
  image_id="$(printf '%s' "$node_json" | jq -r '.imageId // ""')"

  if [[ -z "$image_id" && -n "$TARGET_IMAGE_ID" && "$SKIP_IMAGE_CHECK" == false ]]; then
    image_id="$(compute_image_id_for_instance "$node_id" || true)"
  fi

  printf '%s' "$image_id"
}

ready_active_oci_nodes_count() {
  local pool_json="$1"
  local nodes_json="$2"
  local count=0
  local node_id k8s_name

  while IFS= read -r node_id; do
    [[ -n "$node_id" ]] || continue
    k8s_name="$(k8s_name_for_oci_node_from_json "$nodes_json" "$node_id" || true)"
    if k8s_node_ready_from_json "$nodes_json" "$k8s_name"; then
      count=$((count + 1))
    fi
  done < <(printf '%s' "$pool_json" | active_node_ids)

  printf '%s' "$count"
}

old_oci_node_state() {
  local pool_json="$1"
  local node_id="$2"

  printf '%s' "$pool_json" \
    | jq -r --arg id "$node_id" '
        .data.nodes[]?
        | select(.id == $id)
        | (."lifecycle-state" // .lifecycleState // "")
      ' \
    | head -n1
}

wait_for_pool_and_cluster() {
  local expected_size="$1"
  local replaced_node_id="${2:-}"
  local deadline=$((SECONDS + WAIT_SECONDS))

  while (( SECONDS < deadline )); do
    local pool_json nodes_json state active ready_active k8s_total k8s_ready old_state
    pool_json="$(node_pool_json)"
    nodes_json="$(kubectl_nodes_json)"
    state="$(printf '%s' "$pool_json" | pool_lifecycle_state)"
    active="$(printf '%s' "$pool_json" | active_node_count)"
    ready_active="$(ready_active_oci_nodes_count "$pool_json" "$nodes_json")"
    k8s_total="$(kubectl_node_count_from_json "$nodes_json")"
    k8s_ready="$(ready_node_count_from_json "$nodes_json")"

    if [[ -n "$replaced_node_id" ]]; then
      old_state="$(old_oci_node_state "$pool_json" "$replaced_node_id" || true)"

      if [[ -n "$old_state" && "$old_state" != "DELETED" && "$old_state" != "DELETING" ]]; then
        printf 'Waiting: old OCI node still present with state=%s; nodePool=%s activeNodes=%s/%s readyActiveOciK8sNodes=%s/%s k8sNodes=%s/%s readyK8sNodes=%s/%s\n' \
          "$old_state" "$state" "$active" "$expected_size" "$ready_active" "$expected_size" "$k8s_total" "$expected_size" "$k8s_ready" "$expected_size"
        sleep "$WAIT_INTERVAL_SECONDS"
        continue
      fi
    fi

    if [[ "$state" == "ACTIVE" \
      && "$active" -eq "$expected_size" \
      && "$ready_active" -eq "$expected_size" \
      && "$k8s_total" -eq "$expected_size" \
      && "$k8s_ready" -eq "$expected_size" ]]; then
      return 0
    fi

    printf 'Waiting: nodePool=%s activeNodes=%s/%s readyActiveOciK8sNodes=%s/%s k8sNodes=%s/%s readyK8sNodes=%s/%s\n' \
      "$state" "$active" "$expected_size" "$ready_active" "$expected_size" "$k8s_total" "$expected_size" "$k8s_ready" "$expected_size"
    sleep "$WAIT_INTERVAL_SECONDS"
  done

  return 1
}

longhorn_available() {
  kubectl get namespace longhorn-system >/dev/null 2>&1 || return 1
  kubectl get crd volumes.longhorn.io replicas.longhorn.io nodes.longhorn.io engines.longhorn.io >/dev/null 2>&1 || return 1
}

longhorn_node_ready_from_json() {
  local nodes_json="$1"
  local name="$2"

  printf '%s' "$nodes_json" | jq -e --arg name "$name" '
    .items[]?
    | select(.metadata.name == $name)
    | .status.conditions[]?
    | select(.type == "Ready" and .status == "True")
  ' >/dev/null
}

longhorn_volume_healthy_from_json() {
  local volumes_json="$1"
  local volume="$2"

  printf '%s' "$volumes_json" | jq -e --arg volume "$volume" '
    .items[]?
    | select(.metadata.name == $volume)
    | select((.status.robustness // "") == "healthy")
  ' >/dev/null
}

longhorn_engine_count_for_node_from_json() {
  local engines_json="$1"
  local node="$2"

  printf '%s' "$engines_json" | jq -r --arg node "$node" '
    [ .items[]? | select((.spec.nodeID // "") == $node) ] | length
  '
}

longhorn_replica_count_for_node_from_json() {
  local replicas_json="$1"
  local node="$2"

  printf '%s' "$replicas_json" | jq -r --arg node "$node" '
    [ .items[]? | select((.spec.nodeID // "") == $node) ] | length
  '
}

cleanup_stale_longhorn_nodes_once() {
  [[ "$AUTO_CLEAN_LONGHORN_STALE" == true ]] || return 0
  [[ "$DRY_RUN" == false ]] || return 0
  longhorn_available || return 0

  local k8s_nodes_json volumes_json replicas_json nodes_json engines_json
  k8s_nodes_json="$(kubectl_nodes_json)"
  volumes_json="$(kubectl -n longhorn-system get volumes.longhorn.io -o json)"
  replicas_json="$(kubectl -n longhorn-system get replicas.longhorn.io -o json)"
  nodes_json="$(kubectl -n longhorn-system get nodes.longhorn.io -o json)"
  engines_json="$(kubectl -n longhorn-system get engines.longhorn.io -o json)"

  local lh_node
  while IFS= read -r lh_node; do
    [[ -n "$lh_node" ]] || continue

    # Only clean Longhorn nodes whose Kubernetes node is gone.
    if k8s_node_exists_from_json "$k8s_nodes_json" "$lh_node"; then
      continue
    fi

    # A missing Kubernetes node with a Ready Longhorn node is unexpected. Leave it alone.
    if longhorn_node_ready_from_json "$nodes_json" "$lh_node"; then
      warn "Longhorn node $lh_node is Ready but the Kubernetes node is missing; leaving it untouched"
      continue
    fi

    # Prevent any future scheduling to a stale Longhorn node. This can also make
    # Longhorn remove the node by itself once no engines/replicas remain.
    kubectl -n longhorn-system patch nodes.longhorn.io "$lh_node" \
      --type=merge \
      -p '{"spec":{"allowScheduling":false}}' >/dev/null 2>&1 || true

    local replica_name volume_name replica_state replica_failed_at
    while IFS=$'\t' read -r replica_name volume_name replica_state replica_failed_at; do
      [[ -n "$replica_name" && -n "$volume_name" ]] || continue

      if [[ "$replica_state" != "stopped" && -z "$replica_failed_at" ]]; then
        log "Longhorn node $lh_node is stale but replica $replica_name is state=$replica_state; waiting"
        continue
      fi

      if longhorn_volume_healthy_from_json "$volumes_json" "$volume_name"; then
        log "Deleting stale Longhorn replica $replica_name on removed node $lh_node; volume $volume_name is healthy"
        kubectl -n longhorn-system delete replicas.longhorn.io "$replica_name" --ignore-not-found=true
      else
        log "Longhorn node $lh_node is stale but volume $volume_name is not healthy yet; waiting before deleting replica $replica_name"
      fi
    done < <(
      printf '%s' "$replicas_json" | jq -r --arg node "$lh_node" '
        .items[]?
        | select((.spec.nodeID // "") == $node)
        | [
            .metadata.name,
            (.spec.volumeName // ""),
            (.status.currentState // ""),
            (.spec.failedAt // .status.failedAt // "")
          ]
        | @tsv
      '
    )

    # Refresh after potential deletes.
    replicas_json="$(kubectl -n longhorn-system get replicas.longhorn.io -o json)"
    engines_json="$(kubectl -n longhorn-system get engines.longhorn.io -o json)"

    local remaining_replicas engine_count
    remaining_replicas="$(longhorn_replica_count_for_node_from_json "$replicas_json" "$lh_node")"
    engine_count="$(longhorn_engine_count_for_node_from_json "$engines_json" "$lh_node")"

    if [[ "$remaining_replicas" -eq 0 && "$engine_count" -eq 0 ]]; then
      log "Removing stale Longhorn node $lh_node after Kubernetes node removal"
      kubectl -n longhorn-system delete nodes.longhorn.io "$lh_node" --ignore-not-found=true || true
    else
      log "Longhorn node $lh_node is stale but still has replicas=$remaining_replicas engines=$engine_count; waiting"
    fi
  done < <(printf '%s' "$nodes_json" | jq -r '.items[]?.metadata.name')
}

longhorn_health_counts() {
  local volumes_json="$1"
  local replicas_json="$2"
  local nodes_json="$3"
  local k8s_nodes_json="$4"

  local unhealthy_volumes failed_replicas unready_nodes
  unhealthy_volumes="$(
    printf '%s' "$volumes_json" | jq -r '
      [ .items[]? | select((.status.robustness // "") != "healthy") ] | length
    '
  )"

  failed_replicas="$(
    printf '%s' "$replicas_json" | jq -r '
      [
        .items[]?
        | select(
            ((.spec.failedAt // .status.failedAt // "") != "")
            or
            ((.status.currentState // "") == "stopped")
          )
      ] | length
    '
  )"

  unready_nodes="$(
    jq -n \
      --argjson lh "$nodes_json" \
      --argjson k8s "$k8s_nodes_json" '
      ($k8s.items | map(.metadata.name)) as $k8sNames
      | [
          $lh.items[]?
          | .metadata.name as $name
          | ([.status.conditions[]? | select(.type == "Ready" and .status == "True")] | length) as $ready
          | select($ready == 0)
          | select(($k8sNames | index($name)) == null)
        ] | length
    '
  )"

  printf '%s\t%s\t%s\n' "$unhealthy_volumes" "$failed_replicas" "$unready_nodes"
}

print_longhorn_summary() {
  kubectl -n longhorn-system get nodes.longhorn.io || true

  kubectl -n longhorn-system get volumes.longhorn.io \
    -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness,NODE:.status.currentNodeID,REPLICAS:.spec.numberOfReplicas' || true

  kubectl -n longhorn-system get replicas.longhorn.io \
    -o custom-columns='NAME:.metadata.name,VOLUME:.spec.volumeName,NODE:.spec.nodeID,STATE:.status.currentState,FAILEDAT:.spec.failedAt' || true
}

longhorn_check_once() {
  if ! longhorn_available; then
    log "Longhorn CRDs or namespace not found; treating Longhorn as not installed"
    return 0
  fi

  local volumes_json replicas_json nodes_json k8s_nodes_json counts unhealthy_volumes failed_replicas unready_nodes
  volumes_json="$(kubectl -n longhorn-system get volumes.longhorn.io -o json)"
  replicas_json="$(kubectl -n longhorn-system get replicas.longhorn.io -o json)"
  nodes_json="$(kubectl -n longhorn-system get nodes.longhorn.io -o json)"
  k8s_nodes_json="$(kubectl_nodes_json)"
  counts="$(longhorn_health_counts "$volumes_json" "$replicas_json" "$nodes_json" "$k8s_nodes_json")"
  IFS=$'\t' read -r unhealthy_volumes failed_replicas unready_nodes <<< "$counts"

  if [[ "$unhealthy_volumes" -eq 0 && "$failed_replicas" -eq 0 && "$unready_nodes" -eq 0 ]]; then
    log "Longhorn is healthy"
    return 0
  fi

  warn "Longhorn is not healthy: unhealthyVolumes=$unhealthy_volumes failedOrStoppedReplicas=$failed_replicas unreadyLonghornNodes=$unready_nodes"
  print_longhorn_summary
  return 1
}

wait_for_longhorn_healthy() {
  if ! longhorn_available; then
    log "Longhorn CRDs or namespace not found; skipping Longhorn health wait"
    return 0
  fi

  local deadline=$((SECONDS + LONGHORN_WAIT_SECONDS))

  while (( SECONDS < deadline )); do
    cleanup_stale_longhorn_nodes_once || true

    local volumes_json replicas_json nodes_json k8s_nodes_json counts
    local unhealthy_volumes failed_replicas unready_nodes
    volumes_json="$(kubectl -n longhorn-system get volumes.longhorn.io -o json)"
    replicas_json="$(kubectl -n longhorn-system get replicas.longhorn.io -o json)"
    nodes_json="$(kubectl -n longhorn-system get nodes.longhorn.io -o json)"
    k8s_nodes_json="$(kubectl_nodes_json)"
    counts="$(longhorn_health_counts "$volumes_json" "$replicas_json" "$nodes_json" "$k8s_nodes_json")"
    IFS=$'\t' read -r unhealthy_volumes failed_replicas unready_nodes <<< "$counts"

    if [[ "$unhealthy_volumes" -eq 0 && "$failed_replicas" -eq 0 && "$unready_nodes" -eq 0 ]]; then
      log "Longhorn is healthy"
      return 0
    fi

    printf 'Waiting: Longhorn unhealthyVolumes=%s failedOrStoppedReplicas=%s unreadyLonghornNodes=%s\n' \
      "$unhealthy_volumes" "$failed_replicas" "$unready_nodes"
    print_longhorn_summary
    sleep "$LONGHORN_WAIT_INTERVAL_SECONDS"
  done

  warn "Timed out waiting for Longhorn health after ${LONGHORN_WAIT_SECONDS}s"
  longhorn_check_once || true
  return 1
}

node_needs_replacement() {
  local oci_k8s_version="$1"
  local oci_image_id="$2"
  local k8s_name="$3"

  [[ "$FORCE" == true ]] && return 0

  if [[ -n "$TARGET_K8S_VERSION_NORM" ]]; then
    local actual_version=""
    if [[ -n "$k8s_name" ]]; then
      actual_version="$(normalize_version "$(k8s_node_version "$k8s_name")")"
    fi
    [[ -n "$actual_version" ]] || actual_version="$(normalize_version "$oci_k8s_version")"

    if [[ -n "$actual_version" && "$actual_version" != "$TARGET_K8S_VERSION_NORM" ]]; then
      return 0
    fi
  fi

  if [[ -n "$TARGET_IMAGE_ID" && "$SKIP_IMAGE_CHECK" == false ]]; then
    if [[ -n "$oci_image_id" && "$oci_image_id" != "$TARGET_IMAGE_ID" ]]; then
      return 0
    fi
  fi

  return 1
}

log "Node pool: $NODE_POOL_ID"
[[ -n "$TARGET_K8S_VERSION" ]] && log "Target Kubernetes version: $TARGET_K8S_VERSION"
[[ -n "$TARGET_IMAGE_ID" ]] && log "Target node image id: $TARGET_IMAGE_ID"
[[ "$SKIP_IMAGE_CHECK" == true ]] && warn "Image check disabled"
[[ "$FORCE" == true ]] && warn "Force mode enabled: ACTIVE nodes are candidates"
[[ "$DRY_RUN" == true ]] && warn "Dry run enabled: no nodes will be deleted and Longhorn will not be cleaned"
log "Max replacements this run: $MAX_REPLACEMENTS"

initial_pool_json="$(node_pool_json)"
initial_nodes_json="$(kubectl_nodes_json)"
initial_state="$(printf '%s' "$initial_pool_json" | pool_lifecycle_state)"
expected_size="$(printf '%s' "$initial_pool_json" | desired_size)"
active_count="$(printf '%s' "$initial_pool_json" | active_node_count)"
ready_active_count="$(ready_active_oci_nodes_count "$initial_pool_json" "$initial_nodes_json")"
k8s_total_count="$(kubectl_node_count_from_json "$initial_nodes_json")"
k8s_ready_count="$(ready_node_count_from_json "$initial_nodes_json")"

[[ "$initial_state" == "ACTIVE" ]] || die "Node pool is not ACTIVE, current state: $initial_state"
[[ "$active_count" -eq "$expected_size" ]] || die "Unexpected ACTIVE OCI node count: $active_count/$expected_size"
[[ "$ready_active_count" -eq "$expected_size" ]] || die "Unexpected Ready Kubernetes count for ACTIVE OCI nodes: $ready_active_count/$expected_size"
[[ "$k8s_total_count" -eq "$expected_size" ]] || die "Unexpected Kubernetes node count: $k8s_total_count/$expected_size"
[[ "$k8s_ready_count" -eq "$expected_size" ]] || die "Unexpected Ready Kubernetes node count: $k8s_ready_count/$expected_size"

if [[ "$DRY_RUN" == true ]]; then
  log "Checking Longhorn health once for dry-run"
  longhorn_check_once || warn "A real run would wait for Longhorn to become healthy before replacing nodes"
else
  log "Checking Longhorn health before selecting replacement candidates"
  if ! wait_for_longhorn_healthy; then
    die "Timed out waiting for Longhorn to become healthy before replacement"
  fi
fi

mapfile -t candidates < <(
  printf '%s' "$initial_pool_json" | jq -c '
    .data.nodes[]?
    | {
        id: (.id // ""),
        lifecycle: (."lifecycle-state" // .lifecycleState // ""),
        k8sVersion: (."kubernetes-version" // .kubernetesVersion // ""),
        imageId: (."image-id" // .imageId // ""),
        ociName: (.name // ."display-name" // .displayName // "")
      }
  ' | while read -r node_json; do
    node_id="$(printf '%s' "$node_json" | jq -r '.id')"
    lifecycle="$(printf '%s' "$node_json" | jq -r '.lifecycle')"
    oci_k8s_version="$(printf '%s' "$node_json" | jq -r '.k8sVersion')"
    [[ -n "$node_id" && "$lifecycle" == "ACTIVE" ]] || continue

    k8s_name="$(k8s_name_for_oci_node_from_json "$initial_nodes_json" "$node_id" || true)"
    oci_image_id="$(image_id_for_node "$node_json")"

    if [[ -n "$TARGET_IMAGE_ID" && "$SKIP_IMAGE_CHECK" == false && -z "$oci_image_id" ]]; then
      warn "Could not read image id for $node_id. Image-only detection is unavailable for this node. Use --force if it must be replaced."
    fi

    if node_needs_replacement "$oci_k8s_version" "$oci_image_id" "$k8s_name"; then
      printf '%s' "$node_json" | jq -c --arg k8sName "$k8s_name" --arg imageId "$oci_image_id" '. + {k8sName: $k8sName, imageId: $imageId}'
    fi
  done
)

if [[ "${#candidates[@]}" -eq 0 ]]; then
  log "No nodes need replacement. Nothing to do."
  exit 0
fi

total_candidates="${#candidates[@]}"
if [[ "$MAX_REPLACEMENTS" != "all" && "$total_candidates" -gt "$MAX_REPLACEMENTS" ]]; then
  warn "Limiting replacements from $total_candidates candidates to $MAX_REPLACEMENTS. Re-run the script for the next node or use --max-replacements all explicitly."
  candidates=("${candidates[@]:0:MAX_REPLACEMENTS}")
fi

log "Nodes selected for replacement this run: ${#candidates[@]} of $total_candidates candidates"
printf '%s\n' "${candidates[@]}" | jq -r '"- OCI=\(.id) k8sVersion=\(.k8sVersion) image=\(.imageId) ociName=\(.ociName) k8sName=\(.k8sName)"'

if [[ "$DRY_RUN" == true ]]; then
  exit 0
fi

replaced_count=0
for candidate in "${candidates[@]}"; do
  node_id="$(printf '%s' "$candidate" | jq -r '.id')"

  log "Checking Longhorn health before replacing $node_id"
  if ! wait_for_longhorn_healthy; then
    die "Timed out waiting for Longhorn to become healthy before replacing $node_id"
  fi

  # Re-check just before touching the node. This makes reruns and partially
  # completed runs safe.
  fresh_pool_json="$(node_pool_json)"
  fresh_nodes_json="$(kubectl_nodes_json)"
  fresh_state="$(printf '%s' "$fresh_pool_json" | pool_lifecycle_state)"
  fresh_active="$(printf '%s' "$fresh_pool_json" | active_node_count)"
  fresh_ready_active="$(ready_active_oci_nodes_count "$fresh_pool_json" "$fresh_nodes_json")"
  fresh_k8s_total="$(kubectl_node_count_from_json "$fresh_nodes_json")"
  fresh_k8s_ready="$(ready_node_count_from_json "$fresh_nodes_json")"

  [[ "$fresh_state" == "ACTIVE" ]] || die "Node pool became non-ACTIVE before replacing $node_id: $fresh_state"
  [[ "$fresh_active" -eq "$expected_size" ]] || die "Unexpected ACTIVE OCI node count before replacing $node_id: $fresh_active/$expected_size"
  [[ "$fresh_ready_active" -eq "$expected_size" ]] || die "Unexpected Ready Kubernetes count for ACTIVE OCI nodes before replacing $node_id: $fresh_ready_active/$expected_size"
  [[ "$fresh_k8s_total" -eq "$expected_size" ]] || die "Unexpected Kubernetes node count before replacing $node_id: $fresh_k8s_total/$expected_size"
  [[ "$fresh_k8s_ready" -eq "$expected_size" ]] || die "Unexpected Ready Kubernetes node count before replacing $node_id: $fresh_k8s_ready/$expected_size"

  fresh_node_json="$(printf '%s' "$fresh_pool_json" | jq -c --arg id "$node_id" '.data.nodes[]? | select(.id == $id)' | head -n1)"
  if [[ -z "$fresh_node_json" ]]; then
    log "Skipping $node_id: it is no longer in the node pool"
    continue
  fi

  fresh_lifecycle="$(printf '%s' "$fresh_node_json" | jq -r '."lifecycle-state" // .lifecycleState // ""')"
  if [[ "$fresh_lifecycle" != "ACTIVE" ]]; then
    log "Skipping $node_id: lifecycle state is $fresh_lifecycle"
    continue
  fi

  fresh_k8s_name="$(k8s_name_for_oci_node_from_json "$fresh_nodes_json" "$node_id" || true)"
  fresh_oci_k8s="$(printf '%s' "$fresh_node_json" | jq -r '."kubernetes-version" // .kubernetesVersion // ""')"
  fresh_oci_image="$(image_id_for_node "$fresh_node_json")"

  if ! node_needs_replacement "$fresh_oci_k8s" "$fresh_oci_image" "$fresh_k8s_name"; then
    log "Skipping $node_id: it now matches the target state"
    continue
  fi

  if [[ -n "$fresh_k8s_name" ]]; then
    k8s_node_ready_from_json "$fresh_nodes_json" "$fresh_k8s_name" || die "Kubernetes node $fresh_k8s_name is not Ready before replacement"
  else
    warn "Could not map OCI node $node_id to a Kubernetes node name. Continuing with OCI replacement."
  fi

  log "Replacing OCI node $node_id ${fresh_k8s_name:+($fresh_k8s_name)}"
  oci ce node-pool delete-node \
    --node-pool-id "$NODE_POOL_ID" \
    --node-id "$node_id" \
    --is-decrement-size false \
    --override-eviction-grace-duration "$GRACE_DURATION" \
    --is-force-deletion-after-override-grace-duration false \
    --wait-for-state SUCCEEDED \
    --max-wait-seconds "$WAIT_SECONDS" \
    --wait-interval-seconds "$WAIT_INTERVAL_SECONDS" \
    --force

  log "Waiting for replacement node and Kubernetes readiness"
  if ! wait_for_pool_and_cluster "$expected_size" "$node_id"; then
    die "Timed out waiting for node pool and Kubernetes nodes to return to Ready state"
  fi

  log "Waiting for Longhorn health after replacing $node_id"
  if ! wait_for_longhorn_healthy; then
    die "Timed out waiting for Longhorn to become healthy after replacing $node_id"
  fi

  replaced_count=$((replaced_count + 1))
  log "Replacement completed for $node_id"
done

log "Done. Replaced nodes in this run: $replaced_count"
kubectl get nodes -o wide
