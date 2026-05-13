# -----------------------------------------------------------------------------
# Network — VCN, gateways, route tables, and subnets
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "oke" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = "okevcn"
}

# --- Gateways ----------------------------------------------------------------

resource "oci_core_internet_gateway" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-igw"
  enabled        = true
  vcn_id         = oci_core_vcn.oke.id
}

resource "oci_core_nat_gateway" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-nat"
  vcn_id         = oci_core_vcn.oke.id
}

resource "oci_core_service_gateway" "oci_services" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-sgw"
  vcn_id         = oci_core_vcn.oke.id

  services {
    service_id = local.service_gateway_service_id
  }
}

# --- Route tables ------------------------------------------------------------

# Private route table: worker nodes use NAT + Service Gateway
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-private-rt"
  vcn_id         = oci_core_vcn.oke.id

  route_rules {
    description       = "Internet access through NAT Gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.private.id
  }

  route_rules {
    description       = "OCI services through Service Gateway"
    destination       = "all-arn-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oci_services.id
  }
}

# Public route table: API endpoint and load balancer subnets use Internet Gateway
resource "oci_core_default_route_table" "public" {
  manage_default_resource_id = oci_core_vcn.oke.default_route_table_id
  display_name               = "${var.cluster_name}-public-rt"

  route_rules {
    description       = "Internet access through Internet Gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.public.id
  }
}

# --- Subnets -----------------------------------------------------------------

# Public subnet for the Kubernetes API endpoint
resource "oci_core_subnet" "kubernetes_api" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.kubernetes_api_subnet_cidr
  display_name               = "${var.cluster_name}-k8sapi-subnet"
  dns_label                  = "k8sapi"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_default_route_table.public.id
  security_list_ids          = [oci_core_security_list.kubernetes_api.id]
  vcn_id                     = oci_core_vcn.oke.id
}

# Private subnet for worker nodes
resource "oci_core_subnet" "nodes" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.node_subnet_cidr
  display_name               = "${var.cluster_name}-node-subnet"
  dns_label                  = "nodesubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.node.id]
  vcn_id                     = oci_core_vcn.oke.id
}

# Public subnet for the OCI load balancer used by the gateway service
resource "oci_core_subnet" "service_lb" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.service_lb_subnet_cidr
  display_name               = "${var.cluster_name}-svclb-subnet"
  dns_label                  = "svclbsubnet"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_default_route_table.public.id
  security_list_ids          = [oci_core_security_list.service_lb.id]
  vcn_id                     = oci_core_vcn.oke.id
}
