# -----------------------------------------------------------------------------
# Foundation outputs consumed by terraform/oci-oke
# -----------------------------------------------------------------------------

output "cloudflare_api_token_secret_id" {
  description = "OCI Vault secret OCID for the Cloudflare API token"
  value       = try(oci_vault_secret.cloudflare_api_token[0].id, null)
}

output "cloudflare_api_token_secret_name" {
  description = "OCI Vault secret name used by External Secrets Operator"
  value       = var.cloudflare_api_token_secret_name
}

output "vault_id" {
  description = "Persistent OCI Vault OCID"
  value       = oci_kms_vault.secrets.id
}

output "vault_management_endpoint" {
  description = "OCI Vault management endpoint"
  value       = oci_kms_vault.secrets.management_endpoint
}

output "vault_crypto_endpoint" {
  description = "OCI Vault crypto endpoint"
  value       = oci_kms_vault.secrets.crypto_endpoint
}

output "vault_key_id" {
  description = "OCI Vault KMS key OCID"
  value       = oci_kms_key.secrets.id
}
