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

For changes under `gitops/`:

```bash
git add gitops/...
git commit -m "update gitops"
git push
flux reconcile source git flux-system -n flux-system
```

OpenTofu is not needed for normal GitOps changes.

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

## Node replacement

The OKE stack selects the latest supported Kubernetes version and node image. If existing nodes need replacement after an update:

```bash
cd terraform/oci-oke
./scripts/replace-outdated-nodes.sh --dry-run
./scripts/replace-outdated-nodes.sh
```

The script replaces nodes one at a time.
