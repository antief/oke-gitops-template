# OKE GitOps Template

Bootstrap a small Oracle Kubernetes Engine cluster with OpenTofu and Flux.

The template creates OCI infrastructure, bootstraps Flux, and installs a practical Kubernetes baseline:

- Envoy Gateway and Gateway API for ingress
- OCI Network Load Balancer for public traffic
- ExternalDNS and cert-manager with Cloudflare DNS-01
- External Secrets Operator with OCI Vault
- Longhorn for persistent storage
- metrics-server for Kubernetes resource metrics
- kube-prometheus-stack for metrics, alerting, and Grafana
- Loki and Grafana Alloy for logs
- `whoami` as a public smoke-test app

It is meant to get a new cluster running from code. After bootstrap, keep, change, or remove the defaults to fit your own environment.

## What you need

- OCI CLI configured with `oci setup config`
- an OCI compartment for the cluster
- an OCI Customer Secret Key for the OpenTofu state backend
- a GitHub token with access to the repository created from this template
- a Cloudflare DNS token for your zone
- local tools: `git`, `oci`, `tofu`, `kubectl`, `flux`, `just`, `direnv`, and optionally `gh` and `jq`

See [Configuration](docs/configuration.md) for details.

## Quick start

Create a repository from this template, clone it, and fill in `.env`:

```bash
cp .env.example .env
nano .env
```

Then run:

```bash
just init
just validate
just apply
```

What the commands do:

```text
just init       generate local config and initialize OpenTofu backends
just validate   check local setup, OCI access, and OpenTofu plans
just apply      create or update foundation, OKE, Flux, and GitOps roots
```

## Smoke test

```bash
flux get kustomizations -A
kubectl get nodes
curl -I https://whoami.<your-domain>/
```

For a fuller check, including metrics and logs, see [Operations](docs/operations.md).

## Main commands

```bash
just init       # generate local config and initialize backends
just validate   # check local setup and plans
just plan       # show OpenTofu changes
just apply      # create or update foundation, OKE, and Flux
just destroy    # destroy Flux and OKE, keep foundation
just rebuild    # destroy + apply
```

Use `just destroy` for rebuild testing. Use [Full uninstall](docs/uninstall.md) only when you want to remove everything, including Vault, KMS, and state.

For repositories with branch protection enabled, the pull request helper is useful:

```bash
just pr my-change "docs: describe my change"
```

It creates a branch if needed, commits current changes, opens a pull request, and enables auto-merge. It requires the GitHub CLI (`gh`).

## Layout

```text
terraform/foundation   Vault, KMS key, and shared secrets
terraform/oci-oke      VCN, OKE cluster, node pool, and IAM policy
terraform/flux         Flux bootstrap and root ownership
gitops/                Flux-managed Kubernetes manifests
```

More detail: [Architecture](docs/architecture.md)

## Local files

`.env` is the only file you edit by hand. Do not commit it.

Generated files are local only:

```text
terraform/.envrc
terraform/*/backend.hcl
terraform/*/terraform.tfvars
terraform/*/secrets.auto.tfvars
terraform/*/.terraform/
```

## Documentation

- [Configuration](docs/configuration.md)
- [Operations](docs/operations.md)
- [Architecture](docs/architecture.md)
- [Full uninstall](docs/uninstall.md)
