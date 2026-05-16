# Operations

Use the root `just` commands for normal work.

## Validate

```bash
just init
just validate
```

On a clean install, the Flux plan is skipped until foundation and OKE outputs exist. That is expected before the first `just apply`.

## Apply

```bash
just apply
```

Apply order:

```text
foundation -> OKE -> kubeconfig -> Flux bootstrap -> GitOps roots
```

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

OpenTofu is not needed for normal GitOps changes. Commit the change and let Flux reconcile it.

With branch protection enabled, use the pull request helper:

```bash
just pr update-gitops "update gitops"
```

After the pull request has merged, reconcile Flux if you do not want to wait for the normal interval:

```bash
git switch main
git pull --ff-only
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
curl -I https://whoami.<your-domain>/
```

If `curl` times out but the Gateway has an external address, compare DNS with the LoadBalancer IP:

```bash
kubectl get gateway public -n envoy-gateway-system
kubectl get svc -n envoy-gateway-system --field-selector spec.type=LoadBalancer
dig +short whoami.<your-domain>
curl -k -I --resolve whoami.<your-domain>:443:<load-balancer-ip> https://whoami.<your-domain>/
```

If the `--resolve` test works but normal DNS does not, remove stale Cloudflare `A`/`AAAA` records and matching ExternalDNS TXT ownership records for that hostname, or intentionally reuse the old `EXTERNAL_DNS_TXT_OWNER_ID`.

## Observability checks

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

## OKE managed agents

The template disables optional OKE managed observability agents with node labels.

```bash
kubectl -n kube-system get ds,pods | grep -E 'oke-dataplane|node-problem|NAME' || true
```

The expected DaemonSet state is `DESIRED 0` for `oke-dataplane-observability-agent` and `oke-node-problem-detector`.

## Node replacement

The OKE stack selects the latest supported Kubernetes version and node image. If existing nodes need replacement after an update:

```bash
cd terraform/oci-oke
./scripts/replace-outdated-nodes.sh --dry-run
./scripts/replace-outdated-nodes.sh
```

The script replaces nodes one at a time.
