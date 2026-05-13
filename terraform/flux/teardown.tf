# -----------------------------------------------------------------------------
# GitOps root Kustomizations managed for orderly teardown
# -----------------------------------------------------------------------------
#
# The root Flux Kustomization manifests live in GitOps and are the source of truth
# for names, paths, timing, wait behavior, and postBuild settings.
#
# OpenTofu manages only the teardown ownership and ordering contract so destroy can
# remove the GitOps roots before Flux uninstall.
#
# Root Kustomization names are intentionally a stable API:
#   infra-controllers, infra-configs, infra-addons, apps
#
# Internal GitOps paths and layer contents may change over time, as long as the
# root YAML files keep these names and are updated in GitOps.
#
# Destroy order matters:
#   apps -> infra-addons -> infra-configs -> infra-controllers -> Flux

locals {
  cluster_gitops_path = "${path.module}/../../gitops/clusters/oke_cluster"
}

resource "kubernetes_manifest" "apps" {
  manifest = yamldecode(file("${local.cluster_gitops_path}/apps.yaml"))

  depends_on = [
    kubernetes_manifest.infra_addons,
  ]
}

resource "kubernetes_manifest" "infra_addons" {
  manifest = yamldecode(file("${local.cluster_gitops_path}/infra-addons.yaml"))

  depends_on = [
    kubernetes_manifest.infra_configs,
  ]
}

resource "kubernetes_manifest" "infra_configs" {
  manifest = yamldecode(file("${local.cluster_gitops_path}/infra-configs.yaml"))

  depends_on = [
    kubernetes_manifest.infra_controllers,
    kubernetes_config_map_v1.flux_cluster_vars,
  ]
}

resource "kubernetes_manifest" "infra_controllers" {
  manifest = yamldecode(file("${local.cluster_gitops_path}/infra-controllers.yaml"))

  depends_on = [
    flux_bootstrap_git.gitops,
  ]
}
