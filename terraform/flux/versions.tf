# -----------------------------------------------------------------------------
# Terraform version and provider requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = "~> 1.11"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 8.3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.0"
    }

    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.8.6"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider configuration
# -----------------------------------------------------------------------------

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
