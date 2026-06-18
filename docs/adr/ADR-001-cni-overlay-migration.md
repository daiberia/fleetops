# ADR-001 — CNI migration to Overlay and the quota incident

**Date:** 2025  
**Status:** Resolved

---

## Context

The original AKS cluster was provisioned with the default kubenet CNI. In kubenet mode, each pod receives an IP address from the node's VNet subnet. With a `/24` subnet and AKS reserving addresses for system components, the effective pod limit per node was approximately 30 pods — well below the 110-pod maximum for a `Standard_D2as_v4` node.

As the observability stack (Prometheus, Grafana) and ArgoCD were added, the cluster began hitting this limit. The fix was to migrate to CNI Overlay, which assigns pod IPs from a separate `pod_cidr` (`192.168.0.0/16`) instead of the VNet subnet, removing the subnet-size constraint and raising the pod limit to 110.

---

## The incident

AKS does not support in-place CNI migration on an existing nodepool. The documented path is to drain the node, recreate the nodepool with the new CNI, and reschedule pods. On a single-node cluster this means the node must be taken offline entirely.

During the attempted in-place migration, AKS triggered a nodepool upgrade that required a surge node — a second `Standard_D2as_v4` instance to hold workloads during the drain. This exceeded the Azure for Students subscription quota of 4 vCPU total (2 vCPU in use + 2 vCPU surge = 4 vCPU requested, but AKS also needs headroom for the control plane operations).

The cluster entered `ProvisioningState: Failed`. Recovery options within the existing cluster were exhausted.

**Resolution:** the AKS cluster was destroyed manually (`az aks delete`) and recreated via `terraform apply` with the correct CNI configuration from the start:

```hcl
network_plugin      = "azure"
network_plugin_mode = "overlay"
pod_cidr            = "192.168.0.0/16"
max_pods            = 110
```

The rest of the infrastructure (ACR, Key Vault, LAW, Sentinel, VNet, Managed Identity) was unaffected and remained intact. Recreating only the AKS cluster took approximately 4 minutes after the Terraform fix.

---

## Decision

Provision AKS with CNI Overlay from the start. Never attempt in-place CNI migration on a quota-constrained subscription.

`postgres` was moved outside ArgoCD as a secondary consequence of this incident — during post-recreation testing, the AKS control plane was restoring `konnectivity-agent-autoscaler` and other high-priority system pods on cluster restart, which were evicting `postgres-0`. Adding `priorityClassName: system-cluster-critical` to the StatefulSet resolved this, but ArgoCD does not support this field in its Application sync without additional configuration. The StatefulSet is now managed directly with `kubectl` and excluded from GitOps.

---

## Consequences

- Pod limit is no longer a binding constraint. CPU is the current binding constraint (~1847m / 1900m allocatable at steady state).
- Any future Kubernetes version upgrade that triggers a nodepool rolling update must be preceded by a quota check: `az vm list-usage --location francecentral`. With `upgrade_settings.max_surge = "1"` (required by azurerm v3 — v4 supports `max_unavailable`), a K8s version upgrade will request a second node and will fail if quota is exhausted.
- `postgres` StatefulSet is outside GitOps. Changes to the postgres StatefulSet require manual `kubectl apply`. This is an accepted trade-off for stability on cluster restart.

---

## Residual risk

azurerm provider v3 does not support `max_unavailable` in `upgrade_settings`. Migration to azurerm v4 would allow setting `max_unavailable = 1` and `max_surge = 0`, eliminating the quota risk on K8s version upgrades. This is deferred — v4 introduces breaking changes across Sentinel and AAD RBAC resources that require a broader refactor.
