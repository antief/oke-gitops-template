# -----------------------------------------------------------------------------
# IAM — Dynamic groups and policies for OKE worker nodes
# -----------------------------------------------------------------------------

resource "oci_identity_dynamic_group" "oke_worker_instances" {
  compartment_id = var.tenancy_ocid
  name           = local.iam_worker_dynamic_group_name
  description    = "OKE worker nodes for ${var.cluster_name}"

  matching_rule = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "oke_worker_storage" {
  compartment_id = var.tenancy_ocid
  name           = local.iam_worker_storage_policy_name
  description    = "Allow OKE workers to manage block volume attachments for node storage"

  statements = [
    "Allow dynamic-group ${local.iam_worker_dynamic_group_name} to manage instance-family in tenancy",
    "Allow dynamic-group ${local.iam_worker_dynamic_group_name} to use volume-family in tenancy",
  ]
}

resource "oci_identity_policy" "oke_worker_vault_secrets" {
  compartment_id = var.tenancy_ocid
  name           = local.iam_worker_vault_secrets_policy_name
  description    = "Allow OKE workers to read OCI Vault secret bundles for External Secrets Operator"

  statements = [
    "Allow dynamic-group ${local.iam_worker_dynamic_group_name} to read vaults in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${local.iam_worker_dynamic_group_name} to read secret-bundles in compartment id ${var.compartment_ocid}",
  ]
}
