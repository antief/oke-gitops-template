# -----------------------------------------------------------------------------
# Core outputs
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "OKE cluster OCID"
  value       = oci_containerengine_cluster.oke.id
}

output "cluster_name" {
  description = "OKE cluster name"
  value       = oci_containerengine_cluster.oke.name
}

output "kubernetes_version" {
  description = "Automatically selected Kubernetes version"
  value       = local.latest_kubernetes_version
}

output "node_pool_id" {
  description = "OKE node pool OCID"
  value       = oci_containerengine_node_pool.workers.id
}

output "node_image_name" {
  description = "Automatically selected OKE node image name"
  value       = local.latest_node_image_name
}

output "node_image_id" {
  description = "Automatically selected OKE node image OCID"
  value       = local.latest_node_image_id
}

output "api_endpoint_subnet_id" {
  description = "Kubernetes API endpoint subnet OCID"
  value       = oci_core_subnet.kubernetes_api.id
}

output "service_lb_subnet_id" {
  description = "Service load balancer subnet OCID"
  value       = oci_core_subnet.service_lb.id
}
