# -----------------------------------------------------------------------------
# Security lists for each subnet
#
# Three subnets, three security lists:
#   - service_lb:     public ingress on 80/443, egress to node ports
#   - node:           control plane, LB, node-to-node traffic
#   - kubernetes_api: public kubectl access (restricted by var.api_endpoint_allowed_cidrs)
#
# Flannel overlay networking does not use a separate VCN pod subnet.
# -----------------------------------------------------------------------------

# --- Service load balancer security list ------------------------------------

resource "oci_core_security_list" "service_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-svclb-sl"
  vcn_id         = oci_core_vcn.oke.id

  dynamic "ingress_security_rules" {
    for_each = var.service_lb_tcp_ingress
    content {
      protocol    = "6"
      source      = "0.0.0.0/0"
      description = ingress_security_rules.value.description

      tcp_options {
        min = ingress_security_rules.value.min
        max = ingress_security_rules.value.max
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.service_lb_udp_ingress
    content {
      protocol    = "17"
      source      = "0.0.0.0/0"
      description = ingress_security_rules.value.description

      udp_options {
        min = ingress_security_rules.value.min
        max = ingress_security_rules.value.max
      }
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Service load balancers to internet"
  }

  egress_security_rules {
    protocol    = "6"
    destination = var.node_subnet_cidr
    description = "Service load balancers to node ports TCP"

    tcp_options {
      min = 30000
      max = 32767
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = var.node_subnet_cidr
    description = "Service load balancers to kube-proxy TCP"

    tcp_options {
      min = 10256
      max = 10256
    }
  }

  egress_security_rules {
    protocol    = "17"
    destination = var.node_subnet_cidr
    description = "Service load balancers to node ports UDP"

    udp_options {
      min = 30000
      max = 32767
    }
  }

  egress_security_rules {
    protocol    = "17"
    destination = var.node_subnet_cidr
    description = "Service load balancers to kube-proxy UDP"

    udp_options {
      min = 10256
      max = 10256
    }
  }
}

# --- Node security list ------------------------------------------------------

resource "oci_core_security_list" "node" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-node-sl"
  vcn_id         = oci_core_vcn.oke.id

  # --- Ingress ---

  ingress_security_rules {
    protocol    = "6"
    source      = var.kubernetes_api_subnet_cidr
    description = "Control plane to kubelet"

    tcp_options {
      min = 10250
      max = 10250
    }
  }


  ingress_security_rules {
    protocol    = "all"
    source      = var.node_subnet_cidr
    description = "Node to node"
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP path discovery"

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.service_lb_subnet_cidr
    description = "Service load balancers to node ports TCP"

    tcp_options {
      min = 30000
      max = 32767
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.service_lb_subnet_cidr
    description = "Service load balancers to kube-proxy TCP"

    tcp_options {
      min = 10256
      max = 10256
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = var.service_lb_subnet_cidr
    description = "Service load balancers to node ports UDP"

    udp_options {
      min = 30000
      max = 32767
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = var.service_lb_subnet_cidr
    description = "Service load balancers to kube-proxy UDP"

    udp_options {
      min = 10256
      max = 10256
    }
  }

  # --- Egress ---

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Nodes to internet"
  }

  egress_security_rules {
    protocol    = "all"
    destination = var.node_subnet_cidr
    description = "Node to node"
  }

  egress_security_rules {
    protocol    = "6"
    destination = var.kubernetes_api_subnet_cidr
    description = "Nodes to Kubernetes API"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = var.kubernetes_api_subnet_cidr
    description = "Nodes to Kubernetes API metrics"

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  egress_security_rules {
    protocol         = "6"
    destination      = "all-arn-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    description      = "Nodes to OCI services"
  }

  egress_security_rules {
    protocol    = "1"
    destination = "0.0.0.0/0"
    description = "ICMP path discovery"

    icmp_options {
      type = 3
      code = 4
    }
  }

}

# --- Kubernetes API endpoint security list -----------------------------------

resource "oci_core_security_list" "kubernetes_api" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-k8sapi-sl"
  vcn_id         = oci_core_vcn.oke.id

  dynamic "ingress_security_rules" {
    for_each = var.api_endpoint_allowed_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "Public kubectl access"

      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.node_subnet_cidr
    description = "Nodes to Kubernetes API"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.node_subnet_cidr
    description = "Nodes to Kubernetes API metrics"

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = var.node_subnet_cidr
    description = "ICMP path discovery from nodes"

    icmp_options {
      type = 3
      code = 4
    }
  }


  egress_security_rules {
    protocol         = "6"
    destination      = "all-arn-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    description      = "API endpoint to OCI services"
  }

  egress_security_rules {
    protocol         = "1"
    destination      = "all-arn-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    description      = "ICMP path discovery to OCI services"

    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = var.node_subnet_cidr
    description = "API endpoint to kubelet"

    tcp_options {
      min = 10250
      max = 10250
    }
  }

  egress_security_rules {
    protocol    = "1"
    destination = var.node_subnet_cidr
    description = "ICMP path discovery to nodes"

    icmp_options {
      type = 3
      code = 4
    }
  }

}
