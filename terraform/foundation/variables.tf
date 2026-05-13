# OCI authentication

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
  sensitive   = true
}

variable "compartment_ocid" {
  description = "Compartment where shared foundation resources are created"
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API key"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the OCI API private key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI region"
  type        = string
}

# OCI Vault

variable "vault_display_name" {
  description = "Display name for the persistent OCI Vault"
  type        = string
  default     = "oke-vault"
}

variable "vault_key_display_name" {
  description = "Display name for the persistent OCI Vault key"
  type        = string
  default     = "oke-secrets-key"
}

# DNS / certificates

variable "cloudflare_api_token" {
  description = "Cloudflare API token stored in OCI Vault for External Secrets Operator"
  type        = string
  sensitive   = true
}

variable "vault_store_cloudflare_api_token" {
  description = "Store Cloudflare API token in OCI Vault"
  type        = bool
  default     = true
}

variable "cloudflare_api_token_secret_name" {
  description = "OCI Vault secret name for the Cloudflare API token"
  type        = string
  default     = "cloudflare-api-token"
}
