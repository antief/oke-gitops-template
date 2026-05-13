# Full uninstall

Use this when you want to remove everything created by this repository, including foundation resources and OpenTofu state.

For normal rebuilds, use:

```bash
just rebuild
```

## 1. Load the right environment

Run from the clone that points to the environment you want to remove:

```bash
just init
just validate
```

If you changed state bucket or prefix, run:

```bash
just reinit
just validate
```

Do not use `tofu init -migrate-state` for cleanup unless you are intentionally migrating state.

## 2. Destroy Flux and OKE

```bash
just destroy
```

This removes Flux-managed workloads and the OKE cluster layer. Foundation remains.

## 3. Destroy foundation

Vault and KMS use `prevent_destroy = true`. Remove that guard locally for full uninstall only.

Edit `terraform/foundation/vault.tf` and remove this block from both `oci_kms_vault.secrets` and `oci_kms_key.secrets`:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Then destroy foundation:

```bash
direnv exec terraform bash -c 'cd terraform/foundation && tofu destroy'
```

Restore the guard after destroy:

```bash
git restore terraform/foundation
```

Do not commit the temporary `prevent_destroy` removal.

OCI may schedule Vault and KMS deletion instead of removing them immediately.

## 4. Remove state objects

Only do this after the resources are destroyed:

```bash
set -a
source .env
set +a

NS="$(oci os ns get --profile "${OCI_PROFILE:-DEFAULT}" --raw-output)"

oci os object bulk-delete \
  --namespace-name "$NS" \
  --bucket-name "$TOFU_STATE_BUCKET" \
  --prefix "${TOFU_STATE_PREFIX}/" \
  --force \
  --profile "${OCI_PROFILE:-DEFAULT}"
```

If the bucket was dedicated to this environment, delete the empty bucket too.

## 5. Delete external credentials

Delete credentials created for this install:

- OCI Customer Secret Key
- GitHub token
- Cloudflare DNS token

Delete them only after uninstall has completed.

## 6. Remove local generated files

```bash
rm -f .env
rm -f terraform/.envrc
rm -f terraform/*/backend.hcl
rm -f terraform/*/secrets.auto.tfvars
rm -f terraform/*/terraform.tfvars
rm -rf terraform/*/.terraform
rm -f terraform/*/.terraform.lock.hcl.backup

git status --short
```
