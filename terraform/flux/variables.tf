# OCI authentication

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
  sensitive   = true
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

# GitOps repository

variable "github_owner" {
  description = "GitHub owner or organization for the Flux GitOps repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name for the Flux GitOps repository"
  type        = string
}

variable "github_branch" {
  description = "Git branch reconciled by Flux"
  type        = string
  default     = "main"
}

variable "github_username" {
  description = "Username used for Git HTTPS authentication. With GitHub PATs this can be any non-empty string."
  type        = string
  default     = "git"
}

variable "github_token" {
  description = "GitHub PAT used by the Flux provider for HTTPS bootstrap"
  type        = string
  sensitive   = true
}

variable "flux_gitops_path" {
  description = "Repository path reconciled by the bootstrapped Flux installation"
  type        = string
  default     = "gitops/clusters/oke_cluster"
}

# OKE remote state

variable "oci_oke_state_bucket" {
  description = "S3-compatible backend bucket containing the OKE state"
  type        = string
  default     = "terraform-state"
}

variable "oci_oke_state_key" {
  description = "S3-compatible backend key for the OKE state"
  type        = string
  default     = "oke/terraform.tfstate"
}

variable "oci_oke_state_region" {
  description = "S3-compatible backend region for the OKE state"
  type        = string
  default     = "eu-stockholm-1"
}

variable "oci_oke_state_endpoint" {
  description = "OCI Object Storage S3-compatible endpoint for the OKE state"
  type        = string
}

# Foundation remote state

variable "foundation_state_bucket" {
  description = "S3-compatible backend bucket containing the foundation state"
  type        = string
  default     = "terraform-state"
}

variable "foundation_state_key" {
  description = "S3-compatible backend key for the foundation state"
  type        = string
  default     = "oke/foundation.tfstate"
}

variable "foundation_state_region" {
  description = "S3-compatible backend region for the foundation state"
  type        = string
  default     = "eu-stockholm-1"
}

variable "foundation_state_endpoint" {
  description = "OCI Object Storage S3-compatible endpoint for the foundation state"
  type        = string
}

# Cluster-specific GitOps values

variable "base_domain" {
  description = "Base DNS domain for public cluster hostnames"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email address used for Let's Encrypt ACME registration"
  type        = string
}

variable "external_dns_txt_owner_id" {
  description = "ExternalDNS TXT registry owner ID for this cluster"
  type        = string
}

variable "gateway_tls_secret_name" {
  description = "Kubernetes TLS Secret name used by the public Gateway wildcard HTTPS listener"
  type        = string
}

variable "cloudflare_api_token_k8s_secret_name" {
  description = "Kubernetes Secret name containing the Cloudflare API token for cert-manager and external-dns"
  type        = string
  default     = "cloudflare-api-token-secret"
}

variable "cluster_name" {
  description = "Cluster name used for Flux post-build substitutions."
  type        = string
  default     = "oke-cluster"
}
