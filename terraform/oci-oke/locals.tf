# -----------------------------------------------------------------------------
# Data sources used across multiple files
# -----------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_services" "oci_services" {}

data "oci_containerengine_cluster_option" "available_versions" {
  cluster_option_id              = "all"
  compartment_id                 = var.compartment_ocid
  should_list_all_patch_versions = true
}

data "oci_containerengine_node_pool_option" "available_images" {
  node_pool_option_id            = "all"
  compartment_id                 = var.compartment_ocid
  node_pool_k8s_version          = local.latest_kubernetes_version
  node_pool_os_type              = var.node_pool_os_type
  node_pool_os_arch              = var.node_pool_os_arch
  should_list_all_patch_versions = true
}

data "oci_identity_fault_domains" "availability_domain" {
  compartment_id      = var.tenancy_ocid
  availability_domain = local.availability_domain
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Shared tags applied to all resources
  common_tags = {
    managed-by = "terraform"
    stack      = "oke"
  }

  cluster_tags = merge(local.common_tags, {
    OKEclusterName = var.cluster_name
  })

  node_pool_tags = merge(local.common_tags, {
    OKEnodePoolName = var.node_pool_name
  })

  # Always use the first availability domain in the region
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  # Service Gateway: resolve the "All Services" service ID dynamically
  service_gateway_service_id = one([
    for service in data.oci_core_services.oci_services.services : service.id
    if length(regexall("All .* Services In Oracle Services Network", service.name)) > 0
  ])

  # Kubernetes: always select the latest available version
  latest_kubernetes_version = reverse(sort(data.oci_containerengine_cluster_option.available_versions.kubernetes_versions))[0]

  # Node image: always select the latest image for the configured OS type and arch
  node_source_map = {
    for source in data.oci_containerengine_node_pool_option.available_images.sources : source.source_name => source.image_id
  }
  latest_node_image_name = reverse(sort(keys(local.node_source_map)))[0]
  latest_node_image_id   = local.node_source_map[local.latest_node_image_name]

  # Fault domains: spread nodes across all 3 fault domains for HA
  fault_domains = slice(
    [for fd in data.oci_identity_fault_domains.availability_domain.fault_domains : fd.name],
    0,
    3
  )
}
