# -----------------------------------------------------------------------------
# Remote state inputs
# -----------------------------------------------------------------------------

data "terraform_remote_state" "oci_oke" {
  backend = "s3"

  config = {
    bucket = var.oci_oke_state_bucket
    key    = var.oci_oke_state_key
    region = var.oci_oke_state_region

    endpoint = var.oci_oke_state_endpoint

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}

data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = var.foundation_state_bucket
    key    = var.foundation_state_key
    region = var.foundation_state_region

    endpoint = var.foundation_state_endpoint

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}

locals {
  cluster_id                       = data.terraform_remote_state.oci_oke.outputs.cluster_id
  foundation_vault_id              = data.terraform_remote_state.foundation.outputs.vault_id
  cloudflare_api_token_secret_name = data.terraform_remote_state.foundation.outputs.cloudflare_api_token_secret_name
}
