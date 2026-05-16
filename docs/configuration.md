# Configuration

All user-provided settings live in `.env`.

```bash
cp .env.example .env
nano .env
```

Run `just init` after changing `.env`. It generates the local OpenTofu config files and creates the state bucket if needed.

## OCI

```bash
OCI_PROFILE=DEFAULT
OCI_REGION=eu-stockholm-1
OCI_COMPARTMENT_OCID=ocid1.compartment.oc1...
```

`OCI_PROFILE=DEFAULT` matches the profile created by `oci setup config`. The helper reads tenancy OCID, user OCID, fingerprint, private key path, and region from that profile unless you set them directly in `.env`.

Use a dedicated child compartment if possible. Root tenancy works in a personal tenancy, but a child compartment is easier to clean up and safer for testing.

The worker node dynamic group matches compute instances by compartment. If the compartment contains unrelated compute instances, adjust the IAM matching rule before applying.

## OpenTofu state

```bash
TOFU_STATE_BUCKET=terraform-state
TOFU_STATE_PREFIX=oke
AWS_ACCESS_KEY_ID='<oci-customer-secret-key-access-key>'
AWS_SECRET_ACCESS_KEY='<oci-customer-secret-key-secret>'
```

State is stored in OCI Object Storage through the S3-compatible API. Use a unique `TOFU_STATE_PREFIX` for each environment.

## GitHub and Flux

```bash
GITHUB_OWNER=your-github-user-or-org
GITHUB_REPOSITORY=your-repository
GITHUB_BRANCH=main
GITHUB_TOKEN='<github-token-with-repo-access>'
```

Use a fine-grained GitHub token scoped to the repository created from this template.

Minimum practical permissions:

```text
Contents: read and write
Metadata: read
```

## DNS and TLS

```bash
BASE_DOMAIN=example.com
LETSENCRYPT_EMAIL=admin@example.com
CLOUDFLARE_API_TOKEN='<cloudflare-dns-token>'
```

Cloudflare token permissions:

```text
Zone: DNS: Edit
Zone: Zone: Read
Resource: selected DNS zone
```

The token is stored in OCI Vault. External Secrets Operator syncs it into Kubernetes for cert-manager and ExternalDNS.

## Cluster sizing

Defaults are set for a small ARM-based OKE cluster:

```bash
CLUSTER_NAME=oke-cluster
NODE_POOL_NAME=pool1
NODE_COUNT=3
NODE_OCPUS=1
NODE_MEMORY_GBS=8
NODE_BOOT_VOLUME_SIZE_GBS=66
```

Restrict the Kubernetes API endpoint to your own IP or trusted CIDR:

```bash
API_ENDPOINT_ALLOWED_CIDRS='["1.2.3.4/32"]'
```

## Storage

Longhorn is the default StorageClass. General-purpose volumes use three replicas by default, which matches the default three-node cluster.

If you intentionally run fewer than three nodes, reduce the Longhorn replica count before relying on dynamically provisioned volumes.

The template also creates `longhorn-observability`, a two-replica StorageClass for Prometheus and Loki. This keeps the observability baseline practical on a small cluster.

## Observability

The template installs:

- kube-prometheus-stack for metrics, alerts, and Grafana
- Loki for logs
- Grafana Alloy as an API-based Kubernetes log collector

Prometheus and Loki use 10 GiB Longhorn volumes with seven-day retention. Alloy drops log entries older than 30 minutes before sending them to Loki, which avoids old API backfill data being rejected during bootstrap or rebuilds.

Optional OKE managed observability agents are disabled with node labels because the template provides its own stack.

## ExternalDNS ownership

ExternalDNS uses TXT records to track DNS ownership.

If you reuse hostnames from an older cluster, remove the old ExternalDNS-managed `A`/`AAAA` records and matching TXT ownership records before bootstrapping. Alternatively, intentionally reuse the old owner id:

```bash
EXTERNAL_DNS_TXT_OWNER_ID='<old-owner-id>'
```

For a new install with unused hostnames, leave `EXTERNAL_DNS_TXT_OWNER_ID` empty.

## Generated files

`just init` writes local files under `terraform/`:

```text
terraform/.envrc
terraform/*/backend.hcl
terraform/*/secrets.auto.tfvars
terraform/*/terraform.tfvars
```

They are ignored by Git and must stay local.
