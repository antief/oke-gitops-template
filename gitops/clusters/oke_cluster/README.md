# Cluster entrypoint

Flux starts from this directory.

Root Kustomizations:

```text
infra-controllers -> infra-configs -> infra-addons -> apps
```

Files:

- `infra-controllers.yaml` installs CRDs, operators, and core controllers
- `infra-configs.yaml` applies shared cluster configuration
- `infra-addons.yaml` installs add-ons that depend on config
- `apps.yaml` applies example workloads last
- `flux-system/` contains Flux bootstrap manifests

The root names are used by the OpenTofu Flux stack during destroy. Rename them only if you also update `terraform/flux`.

In the template repository, `flux-system/gotk-sync.yaml` contains a placeholder Git URL. `just apply` runs Flux bootstrap and rewrites it to the repository configured in `.env`.
