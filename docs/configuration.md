# Configuration

Copy the example file and fill in your own values:

```bash
cp .env.example .env
$EDITOR .env
```

Run `just init` after changing `.env`.

## OCI

```bash
OCI_PROFILE=DEFAULT
OCI_REGION=eu-stockholm-1
OCI_COMPARTMENT_OCID=ocid1.compartment.oc1...
```

`OCI_PROFILE=DEFAULT` matches the profile created by `oci setup config`. Change it only if you use another OCI CLI profile.

The target compartment can be the root tenancy or a child compartment.

A dedicated child compartment is recommended for testing and rebuilds because it keeps cluster resources easy to identify and clean up.

The worker node dynamic group matches compute instances by compartment. If you use a shared compartment with unrelated compute instances, adjust the IAM matching rule before applying.

For a personal tenancy, the default OCI CLI user usually has the required permissions. In restricted tenancies, the user must be allowed to create the IAM dynamic group and policies used by the cluster.

`just init` can read these from the selected OCI CLI profile:

- tenancy OCID
- user OCID
- API key fingerprint
- API private key path
- region

## OpenTofu state

```bash
TOFU_STATE_BUCKET=terraform-state
TOFU_STATE_PREFIX=oke
AWS_ACCESS_KEY_ID='<oci-customer-secret-key-access-key>'
AWS_SECRET_ACCESS_KEY='<oci-customer-secret-key-secret>'
```

OpenTofu state is stored in OCI Object Storage through the [S3-compatible API](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm). `just init` creates the bucket if it does not exist.

Use a unique `TOFU_STATE_PREFIX` for each environment.

## GitHub and Flux

```bash
GITHUB_OWNER=your-github-user-or-org
GITHUB_REPOSITORY=your-repository
GITHUB_BRANCH=main
GITHUB_TOKEN='<github-token-with-repo-access>'
```

Use a fine-grained token scoped to the repository created from this template.

Minimum practical permissions:

```text
Contents: read and write
Metadata: read
```

Flux bootstrap uses this token to write and reconcile Flux manifests.

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

The foundation stack stores the token in OCI Vault. External Secrets Operator reads it from Vault and creates Kubernetes Secrets for cert-manager and ExternalDNS.

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

## ExternalDNS ownership

ExternalDNS uses TXT records to track DNS ownership. If you reuse a DNS zone from an older cluster, either delete the old ExternalDNS-managed `A` and `TXT` records first, or set:

```bash
EXTERNAL_DNS_TXT_OWNER_ID='<old-owner-id>'
```

Leave it empty for a new install.

## Generated files

`just init` writes these local files:

```text
terraform/.envrc
terraform/foundation/backend.hcl
terraform/oci-oke/backend.hcl
terraform/flux/backend.hcl
terraform/foundation/secrets.auto.tfvars
terraform/oci-oke/secrets.auto.tfvars
terraform/flux/secrets.auto.tfvars
terraform/foundation/terraform.tfvars
terraform/oci-oke/terraform.tfvars
terraform/flux/terraform.tfvars
```

They are ignored by Git and must stay local.
