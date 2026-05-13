# -----------------------------------------------------------------------------
# Flux bootstrap
# -----------------------------------------------------------------------------

data "oci_containerengine_cluster_kube_config" "oke" {
  cluster_id    = local.cluster_id
  endpoint      = "PUBLIC_ENDPOINT"
  token_version = "2.0.0"
}

locals {
  kubeconfig   = yamldecode(data.oci_containerengine_cluster_kube_config.oke.content)
  kube_cluster = local.kubeconfig.clusters[0].cluster

  oci_kube_exec_args = [
    "ce",
    "cluster",
    "generate-token",
    "--cluster-id",
    local.cluster_id,
    "--region",
    var.region,
  ]
}

provider "kubernetes" {
  host                   = local.kube_cluster.server
  cluster_ca_certificate = base64decode(local.kube_cluster["certificate-authority-data"])

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "oci"
    args        = local.oci_kube_exec_args
  }
}

provider "flux" {
  kubernetes = {
    host                   = local.kube_cluster.server
    cluster_ca_certificate = base64decode(local.kube_cluster["certificate-authority-data"])

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "oci"
      args        = local.oci_kube_exec_args
    }
  }

  git = {
    url    = "https://github.com/${var.github_owner}/${var.github_repository}.git"
    branch = var.github_branch

    http = {
      username = var.github_username
      password = var.github_token
    }
  }
}

resource "kubernetes_namespace_v1" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

resource "kubernetes_config_map_v1" "flux_cluster_vars" {
  metadata {
    name      = "cluster-vars"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name

    labels = {
      "reconcile.fluxcd.io/watch" = "Enabled"
    }
  }

  data = {
    OCI_REGION                       = var.region
    OCI_VAULT_ID                     = local.foundation_vault_id
    CLOUDFLARE_API_TOKEN_SECRET_NAME = local.cloudflare_api_token_secret_name

    BASE_DOMAIN                          = var.base_domain
    LETSENCRYPT_EMAIL                    = var.letsencrypt_email
    WHOAMI_HOSTNAME                      = "whoami.${var.base_domain}"
    EXTERNAL_DNS_TXT_OWNER_ID            = var.external_dns_txt_owner_id
    GATEWAY_TLS_SECRET_NAME              = var.gateway_tls_secret_name
    CLOUDFLARE_API_TOKEN_K8S_SECRET_NAME = var.cloudflare_api_token_k8s_secret_name
  }
}

resource "flux_bootstrap_git" "gitops" {
  depends_on = [
    kubernetes_config_map_v1.flux_cluster_vars,
  ]

  path               = var.flux_gitops_path
  embedded_manifests = true

  # Keep Git as the source of truth. Destroying the Flux stack must not commit
  # deletions of gotk-components.yaml or gotk-sync.yaml back to the repository.
  delete_git_manifests = false

  # The namespace contains OpenTofu-owned objects during destroy; the OKE stack
  # deletes the whole cluster after this stack has been destroyed.
  keep_namespace = true

  timeouts = {
    create = "15m"
    update = "15m"
    delete = "10m"
  }
}
