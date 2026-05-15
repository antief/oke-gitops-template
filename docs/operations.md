# Operations

Use the root `just` commands for normal work.

## Validate

```bash
just init
just validate
```

On a clean install, the Flux plan is skipped until foundation and OKE state outputs exist. That is expected before the first `just apply`.

## Apply

```bash
just apply
```

Apply order:

1. foundation
2. OKE infrastructure
3. kubeconfig
4. Flux bootstrap
5. Flux root Kustomizations
6. GitOps controllers, configs, add-ons, and apps

## Rebuild

```bash
just rebuild
```

This runs `just destroy` and `just apply`. Foundation is kept.

## Destroy cluster layer

```bash
just destroy
```

This removes Flux and OKE. It does not delete Vault, KMS, or state.

Use [uninstall.md](uninstall.md) for full cleanup.

## GitOps changes

OpenTofu is not needed for normal GitOps changes. Commit the change to the repository watched by Flux and reconcile Flux if you want to apply it immediately.

If the repository uses branch protection, make the change and use the pull request helper:

```bash
just pr update-gitops "update gitops"
```

The helper creates a branch when run from `main`, commits current changes, opens a pull request, and enables auto-merge. It requires the GitHub CLI (`gh`) to be installed and authenticated.

After the pull request has merged, reconcile Flux if you do not want to wait for the normal reconciliation interval:

```bash
git switch main
git pull
flux reconcile source git flux-system -n flux-system
```

If the repository does not use branch protection, a direct commit and push also works:

```bash
git add gitops/...
git commit -m "update gitops"
git push
flux reconcile source git flux-system -n flux-system
```

## Infrastructure changes

For changes under `terraform/` or `.env`:

```bash
just init
just plan
just apply
```

## Smoke tests

```bash
flux get all -A
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get svc -A --field-selector spec.type=LoadBalancer
kubectl get gateway,httproute -A
curl -k -I https://whoami.<your-domain>/
```

Check that optional OKE managed observability agents are disabled:

```bash
kubectl -n kube-system get ds,pods | grep -E 'oke-dataplane|node-problem|NAME' || true
```

The expected DaemonSet state is `DESIRED 0` for `oke-dataplane-observability-agent` and `oke-node-problem-detector`.

Check metrics and logs:

```bash
kubectl top nodes

kubectl -n observability port-forward svc/observability-kube-prometh-prometheus 9090:9090
curl -s 'http://127.0.0.1:9090/-/ready'; echo
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq '.status, (.data.result | length)'

kubectl -n observability port-forward svc/observability-loki-gateway 3101:80
curl -s 'http://127.0.0.1:3101/'; echo
curl -s 'http://127.0.0.1:3101/loki/api/v1/labels' | jq
```

Check that Alloy is not dropping or failing pushes to Loki:

```bash
kubectl -n observability logs deploy/observability-alloy -c alloy --since=30m \
  | grep -E 'permission denied|no such file|status=400|status=500|no schema config|too far behind|level=error' || true
```

A clean result prints no matching lines.

## Node replacement

The OKE stack selects the latest supported Kubernetes version and node image. If existing nodes need replacement after an update:

```bash
cd terraform/oci-oke
./scripts/replace-outdated-nodes.sh --dry-run
./scripts/replace-outdated-nodes.sh
```

The script replaces nodes one at a time.
