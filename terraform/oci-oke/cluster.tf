# -----------------------------------------------------------------------------
# OKE cluster and node pool
# -----------------------------------------------------------------------------

resource "oci_containerengine_cluster" "oke" {
  compartment_id     = var.compartment_ocid
  name               = var.cluster_name
  type               = "BASIC_CLUSTER"
  vcn_id             = oci_core_vcn.oke.id
  kubernetes_version = local.latest_kubernetes_version

  freeform_tags = local.cluster_tags

  # Flannel overlay keeps the template simple and avoids a separate VCN pod subnet.
  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.kubernetes_api.id
  }

  options {
    admission_controller_options {
      is_pod_security_policy_enabled = false
    }

    persistent_volume_config {
      freeform_tags = local.cluster_tags
    }

    service_lb_config {
      freeform_tags = local.cluster_tags
    }

    service_lb_subnet_ids = [oci_core_subnet.service_lb.id]
  }
}

resource "oci_containerengine_node_pool" "workers" {
  cluster_id         = oci_containerengine_cluster.oke.id
  compartment_id     = var.compartment_ocid
  name               = var.node_pool_name
  kubernetes_version = local.latest_kubernetes_version
  node_shape         = var.node_shape

  freeform_tags = local.node_pool_tags

  node_metadata = {
    user_data = base64encode(file("${path.module}/node-cloud-init.sh"))
  }

  initial_node_labels {
    key   = "name"
    value = var.cluster_name
  }

  # Disable optional OKE managed observability agents on worker nodes.
  # The template ships its own Prometheus, Loki, and Alloy stack.
  initial_node_labels {
    key   = "oci.oraclecloud.com/oke-observability-agent-enabled"
    value = "false"
  }

  initial_node_labels {
    key   = "oci.oraclecloud.com/oke-node-problem-detector-enabled"
    value = "false"
  }

  node_config_details {
    size = var.node_count

    freeform_tags = local.node_pool_tags

    placement_configs {
      availability_domain = local.availability_domain
      subnet_id           = oci_core_subnet.nodes.id
      fault_domains       = local.fault_domains
    }

    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }
  }

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.latest_node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_size_gbs
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration = "PT30M"
  }
}
