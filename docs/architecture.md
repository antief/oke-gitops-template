# Architecture

The repository has three OpenTofu stacks and one Flux GitOps tree.

## OpenTofu stacks

```text
terraform/foundation   Vault, KMS key, and shared secrets
terraform/oci-oke      VCN, OKE cluster, node pool, and IAM policy
terraform/flux         Flux bootstrap and root Kustomization ownership
```

`foundation` is kept during normal rebuilds. `oci-oke` and `flux` are rebuildable.

## Cluster layout

The OKE stack creates a basic OKE cluster, one managed node pool, and three subnets:

```text
kubernetes_api   public Kubernetes API endpoint
nodes            private worker nodes
service_lb       public Kubernetes LoadBalancer services
```

The default node pool uses ARM-based `VM.Standard.A1.Flex` nodes. The default is three nodes with one OCPU and 8 GB memory each. Nodes are placed in one availability domain and spread across fault domains when available.

The cluster uses Flannel overlay networking. This keeps the VCN layout small because pod IPs do not need a separate OCI subnet.

## Public traffic

Envoy Gateway creates a Kubernetes `LoadBalancer` service annotated for an OCI Network Load Balancer. The NLB is created in the `service_lb` subnet and exposes HTTP and HTTPS.

Gateway API resources route traffic from the public Gateway to workloads.

ExternalDNS publishes DNS records to Cloudflare.

cert-manager issues TLS certificates with Cloudflare DNS-01.

## GitOps tree

```text
gitops/clusters/oke_cluster        Flux root objects
gitops/infrastructure/core         controllers, configs, and add-ons
gitops/apps                        example workloads
```

Flux applies the roots in this order:

```text
infra-controllers -> infra-configs -> infra-addons -> apps
```

Destroy runs in reverse order before OKE is removed.

## Node count notes

The default manifests are tuned for the default three-node cluster.

One or two node clusters can be used for testing, but adjust storage and observability expectations:

- Longhorn defaults to three replicas per volume. With fewer than three nodes, use a lower Longhorn replica count or accept degraded volumes.
- kube-prometheus-stack runs two Prometheus replicas, two Alertmanager replicas, and two Grafana replicas. Reduce these if a smaller cluster is resource constrained.

Four or more nodes work with the default manifests. Longhorn still creates three replicas per volume by default, and observability still runs two replicas unless you change the Helm values.

Flux itself is not sensitive to the node count in this template.

## Secrets

OpenTofu stores the Cloudflare token in OCI Vault.

External Secrets Operator reads the token from Vault and writes Kubernetes Secrets into the namespaces that need it.