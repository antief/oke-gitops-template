set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    just help

help:
    just --list

init:
    just _configure-local
    direnv allow terraform >/dev/null
    just _init-foundation
    just _init-oke
    just _init-flux

reinit:
    just _configure-local
    direnv allow terraform >/dev/null
    just _reinit-foundation
    just _reinit-oke
    just _reinit-flux

validate: init
    scripts/preflight.sh
    just _plan-foundation
    just _plan-oke
    just _plan-flux

plan: init
    just _plan-foundation
    just _plan-oke
    just _plan-flux

apply: init
    just _apply-foundation
    just _apply-oke
    just _kubeconfig
    just _bootstrap-flux
    just _wait-flux-ready
    just _import-flux-roots
    just _apply-flux

destroy: init
    just _check-teardown-roots
    just _destroy-flux
    just _wait-loadbalancers-gone
    just _destroy-oke

rebuild:
    just destroy
    just apply

_configure-local:
    scripts/init-local-env.sh

_init-foundation:
    direnv exec terraform bash -c 'cd terraform/foundation && tofu init -backend-config=backend.hcl'

_init-oke:
    direnv exec terraform bash -c 'cd terraform/oci-oke && tofu init -backend-config=backend.hcl'

_init-flux:
    direnv exec terraform bash -c 'cd terraform/flux && tofu init -backend-config=backend.hcl'

_reinit-foundation:
    direnv exec terraform bash -c 'cd terraform/foundation && tofu init -reconfigure -backend-config=backend.hcl'

_reinit-oke:
    direnv exec terraform bash -c 'cd terraform/oci-oke && tofu init -reconfigure -backend-config=backend.hcl'

_reinit-flux:
    direnv exec terraform bash -c 'cd terraform/flux && tofu init -reconfigure -backend-config=backend.hcl'

_plan-foundation:
    direnv exec terraform bash -c 'cd terraform/foundation && tofu plan'

_plan-oke:
    direnv exec terraform bash -c 'cd terraform/oci-oke && tofu plan'

_plan-flux:
    direnv exec terraform bash -c ' \
      has_output() { \
        stack="$1"; \
        output="$2"; \
        outputs="$(cd "terraform/$stack" && tofu output -json 2>/dev/null || true)"; \
        printf "%s" "$outputs" | grep -Fq "$output"; \
      }; \
      if ! has_output foundation vault_id || ! has_output foundation cloudflare_api_token_secret_name; then \
        echo "Skipping flux plan because foundation has not been applied yet."; \
        echo "This is expected before the first just apply in a clean-room install."; \
        exit 0; \
      fi; \
      if ! has_output oci-oke cluster_id; then \
        echo "Skipping flux plan because OKE has not been applied yet."; \
        echo "This is expected before the first just apply in a clean-room install."; \
        exit 0; \
      fi; \
      cd terraform/flux && tofu plan'

_apply-foundation: _init-foundation
    direnv exec terraform bash -c 'cd terraform/foundation && tofu apply'

_apply-oke: _init-oke
    direnv exec terraform bash -c 'cd terraform/oci-oke && tofu apply'

_destroy-oke: _init-oke
    direnv exec terraform bash -c 'cd terraform/oci-oke && tofu destroy -auto-approve'

_kubeconfig:
    direnv exec terraform bash -c 'cd terraform/oci-oke && oci ce cluster create-kubeconfig \
      --cluster-id "$(tofu output -raw cluster_id)" \
      --file ~/.kube/config \
      --region "${OCI_REGION:-eu-stockholm-1}" \
      --token-version 2.0.0 \
      --kube-endpoint PUBLIC_ENDPOINT'

_bootstrap-flux: _init-flux
    direnv exec terraform bash -c 'cd terraform/flux && tofu apply -auto-approve \
      -target=kubernetes_namespace_v1.flux_system \
      -target=kubernetes_config_map_v1.flux_cluster_vars \
      -target=flux_bootstrap_git.gitops'

_wait-flux-ready:
    direnv exec terraform bash -c 'kubectl wait --for=condition=Established crd/kustomizations.kustomize.toolkit.fluxcd.io --timeout=180s'
    direnv exec terraform bash -c 'for deployment in source-controller kustomize-controller helm-controller notification-controller; do \
      kubectl -n flux-system rollout status deployment/"$deployment" --timeout=180s; \
    done'

_import-flux-roots: _init-flux
    direnv exec terraform bash -c 'cd terraform/flux && \
      require_root() { \
        name="$1"; \
        if ! kubectl -n flux-system get kustomization "$name" >/dev/null 2>&1; then \
          echo "Root Flux Kustomization $name not found. Did you rename a root Kustomization? Root names are part of the teardown contract." >&2; \
          exit 1; \
        fi; \
      }; \
      import_if_missing() { \
        addr="$1"; \
        id="$2"; \
        if ! tofu state list | grep -Fxq "$addr"; then \
          tofu import "$addr" "$id"; \
        fi; \
      }; \
      require_root apps; \
      require_root infra-addons; \
      require_root infra-configs; \
      require_root infra-controllers; \
      import_if_missing kubernetes_manifest.apps "apiVersion=kustomize.toolkit.fluxcd.io/v1,kind=Kustomization,namespace=flux-system,name=apps"; \
      import_if_missing kubernetes_manifest.infra_addons "apiVersion=kustomize.toolkit.fluxcd.io/v1,kind=Kustomization,namespace=flux-system,name=infra-addons"; \
      import_if_missing kubernetes_manifest.infra_configs "apiVersion=kustomize.toolkit.fluxcd.io/v1,kind=Kustomization,namespace=flux-system,name=infra-configs"; \
      import_if_missing kubernetes_manifest.infra_controllers "apiVersion=kustomize.toolkit.fluxcd.io/v1,kind=Kustomization,namespace=flux-system,name=infra-controllers"'

_apply-flux: _init-flux
    direnv exec terraform bash -c 'cd terraform/flux && tofu apply -auto-approve'

_check-teardown-roots:
    direnv exec terraform bash -c 'check_teardown_roots() { \
      expected="apps infra-addons infra-configs infra-controllers"; \
      msg="Flux root Kustomization set does not match the teardown contract. Expected apps, infra-addons, infra-configs, infra-controllers. Did you rename a root Kustomization without migrating terraform/flux state?"; \
      if ! kubectl get namespace flux-system >/dev/null 2>&1; then \
        return 0; \
      fi; \
      if ! kubectl get crd kustomizations.kustomize.toolkit.fluxcd.io >/dev/null 2>&1; then \
        return 0; \
      fi; \
      if ! roots=$(kubectl -n flux-system get kustomization -o name 2>/dev/null | sed "s#kustomization.kustomize.toolkit.fluxcd.io/##"); then \
        echo "Could not list Flux Kustomizations in flux-system. Refusing to continue destroy." >&2; \
        exit 1; \
      fi; \
      other_roots=$(printf "%s\n" "$roots" | sed "/^$/d" | grep -Fvx "apps" | grep -Fvx "infra-addons" | grep -Fvx "infra-configs" | grep -Fvx "infra-controllers" | grep -Fvx "flux-system" || true); \
      if [ -n "$other_roots" ]; then \
        echo "$msg" >&2; \
        echo "Unexpected Flux Kustomizations:" >&2; \
        echo "$other_roots" >&2; \
        exit 1; \
      fi; \
      found=0; \
      for name in $expected; do \
        if printf "%s\n" "$roots" | grep -Fxq "$name"; then \
          found=$((found + 1)); \
        fi; \
      done; \
      if [ "$found" -eq 4 ]; then \
        return 0; \
      fi; \
      if [ "$found" -eq 0 ]; then \
        return 0; \
      fi; \
      echo "Warning: only some expected Flux root Kustomizations are present. Continuing destroy because no unexpected roots were found." >&2; \
      return 0; \
    }; \
    check_teardown_roots'

_destroy-flux: _init-flux
    direnv exec terraform bash -c 'cd terraform/flux && tofu destroy'

_wait-loadbalancers-gone:
    direnv exec terraform bash -c 'for _ in $(seq 1 60); do \
      if services=$(kubectl get svc -A --field-selector spec.type=LoadBalancer --no-headers 2>/dev/null); then \
        if [ -z "$services" ]; then \
          exit 0; \
        fi; \
      fi; \
      sleep 10; \
    done; \
    echo "Timed out waiting for LoadBalancer Services to disappear before OKE destroy" >&2; \
    kubectl get svc -A --field-selector spec.type=LoadBalancer >&2 || true; \
    exit 1'

pr branch msg:
    #!/usr/bin/env bash
    set -euo pipefail

    branch='{{branch}}'
    msg='{{msg}}'

    if ! command -v gh >/dev/null 2>&1; then
      echo "GitHub CLI 'gh' is required." >&2
      exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
      echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
      exit 1
    fi

    current_branch="$(git branch --show-current)"

    if [ "$current_branch" = "main" ]; then
      git switch -c "$branch"
    elif [ "$current_branch" != "$branch" ]; then
      echo "Current branch is '$current_branch', expected 'main' or '$branch'." >&2
      exit 1
    fi

    if git diff --quiet && git diff --cached --quiet; then
      echo "No changes to commit." >&2
      exit 1
    fi

    git add -A
    git commit -m "$msg"
    git push -u origin HEAD

    if ! gh pr view >/dev/null 2>&1; then
      gh pr create --fill --base main
    fi

    gh pr merge --auto --squash --delete-branch