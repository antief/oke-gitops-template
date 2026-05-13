# OKE GitOps Template

Bootstrap a small Oracle Kubernetes Engine cluster with OpenTofu and Flux.

The template creates OCI infrastructure, bootstraps Flux, and installs a practical Kubernetes baseline: Envoy Gateway, ExternalDNS, cert-manager, External Secrets Operator, Longhorn, kube-prometheus-stack, metrics-server, and a `whoami` test app.

It is meant to get a new cluster running from code. After bootstrap, keep, change, or remove the defaults to fit your own environment.

## What you provide

- OCI CLI profile, usually the `DEFAULT` profile from [`oci setup config`](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliconfigure.htm)
- an OCI [compartment](https://docs.oracle.com/en-us/iaas/Content/Identity/compartments/managingcompartments.htm) for the cluster. A dedicated child compartment is recommended, but root tenancy can also be used in a personal tenancy
- an OCI user/API key with permission to create the required OCI resources. See [API signing keys](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm) and [common IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/commonpolicies.htm)
- OCI [Customer Secret Key](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm) for the OpenTofu state backend
- GitHub token with read/write access to your new repository
- Cloudflare DNS token for your zone
- a Cloudflare-managed DNS zone

The template creates the state bucket if it is missing, then creates the network, OKE cluster, Vault, KMS key, IAM resources, Flux, and Kubernetes components.

## Tools

Install:

- `git`
- `oci`
- `tofu`
- `kubectl`
- `flux`
- `just`
- `direnv`

Configure OCI CLI:

```bash
oci setup config
```

## Quick start

Create a repository from this template, clone it, and fill in `.env`:

```bash
cp .env.example .env
$EDITOR .env
```

Then run:

```bash
just init
just validate
just apply
```

`just init` writes local configuration from `.env`, creates the state bucket if needed, and initializes the OpenTofu backends.

`just validate` checks local files, OCI access, and OpenTofu plans.

`just apply` creates the foundation resources, OKE cluster, kubeconfig, Flux bootstrap, and GitOps roots.

## Smoke test

```bash
flux get kustomizations -A
kubectl get nodes
curl -k -I https://whoami.<your-domain>/
```

For a fuller check, see [Operations](docs/operations.md).

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

## Repository layout

The repository has OpenTofu stacks under `terraform/` and Flux manifests under `gitops/`. See [Architecture](docs/architecture.md) for details.

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
