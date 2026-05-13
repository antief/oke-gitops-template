# -----------------------------------------------------------------------------
# Persistent OCI Vault, KMS key, and shared secrets
#
# This stack is intentionally separate from terraform/oci-oke so the cluster can
# be destroyed and rebuilt without deleting the secrets that GitOps depends on.
# -----------------------------------------------------------------------------

resource "oci_kms_vault" "secrets" {
  compartment_id = var.compartment_ocid
  display_name   = var.vault_display_name
  vault_type     = "DEFAULT"

  freeform_tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_kms_key" "secrets" {
  compartment_id      = var.compartment_ocid
  display_name        = var.vault_key_display_name
  management_endpoint = oci_kms_vault.secrets.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  protection_mode = "SOFTWARE"

  freeform_tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# --- Secrets -----------------------------------------------------------------

resource "oci_vault_secret" "cloudflare_api_token" {
  count          = var.vault_store_cloudflare_api_token ? 1 : 0
  compartment_id = var.compartment_ocid
  secret_name    = var.cloudflare_api_token_secret_name
  vault_id       = oci_kms_vault.secrets.id
  key_id         = oci_kms_key.secrets.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.cloudflare_api_token)
    stage        = "CURRENT"
  }

  freeform_tags = local.common_tags
}
