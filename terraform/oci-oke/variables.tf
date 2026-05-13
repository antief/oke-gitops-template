# OCI authentication

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
  sensitive   = true
}

variable "compartment_ocid" {
  description = "Compartment where the OKE resources are created"
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

# Cluster

variable "cluster_name" {
  description = "OKE cluster name"
  type        = string
  default     = "oke-cluster"
}

# Networking

variable "vcn_cidr" {
  description = "VCN CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_api_subnet_cidr" {
  description = "Public API endpoint subnet CIDR"
  type        = string
  default     = "10.0.0.0/28"
}

variable "node_subnet_cidr" {
  description = "Private worker node subnet CIDR"
  type        = string
  default     = "10.0.10.0/24"
}

variable "service_lb_subnet_cidr" {
  description = "Public service load balancer subnet CIDR"
  type        = string
  default     = "10.0.20.0/24"
}

variable "api_endpoint_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint on TCP/6443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node pool

variable "node_pool_name" {
  description = "OKE node pool name"
  type        = string
  default     = "pool1"
}

variable "node_shape" {
  description = "OKE worker node shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_ocpus" {
  description = "Worker node OCPUs"
  type        = number
  default     = 1
}

variable "node_memory_gbs" {
  description = "Worker node memory in GB"
  type        = number
  default     = 8
}

variable "node_count" {
  description = "Worker node count"
  type        = number
  default     = 3
}

variable "node_boot_volume_size_gbs" {
  description = "Boot volume size for worker nodes. OKE managed nodes require at least 50 GB."
  type        = number
  default     = 50
}

variable "node_pool_os_type" {
  description = "Node pool operating system type filter for automatic image selection"
  type        = string
  default     = "OL8"
}

variable "node_pool_os_arch" {
  description = "Node pool operating system architecture filter for automatic image selection"
  type        = string
  default     = "AARCH64"
}

# Public service ports

variable "service_lb_tcp_ingress" {
  description = "Public TCP listener ports exposed via the OKE service load balancer subnet"
  type = list(object({
    description = string
    min         = number
    max         = number
  }))
  default = [
    {
      description = "HTTP"
      min         = 80
      max         = 80
    },
    {
      description = "HTTPS"
      min         = 443
      max         = 443
    }
  ]
}

variable "service_lb_udp_ingress" {
  description = "Public UDP listener ports exposed via the OKE service load balancer subnet"
  type = list(object({
    description = string
    min         = number
    max         = number
  }))
  default = []
}
