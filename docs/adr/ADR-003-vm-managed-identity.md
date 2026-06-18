# ADR-003 — VM Managed Identity vs Workload Identity

**Date:** 2025  
**Status:** Active

---

## Context

FleetOps pods need to access Azure Key Vault to retrieve three secrets (database password, database URL, JWT secret) via the CSI Secrets Store driver. Two mechanisms are available on AKS for pod-level Azure identity:

**Workload Identity (OIDC + federated credentials)**  
Each pod is associated with a Kubernetes ServiceAccount annotated with a federated credential. The AKS OIDC issuer issues a token that Azure AD verifies to grant the pod an Azure identity. Requires:
- OIDC issuer enabled on the cluster (`--enable-oidc-issuer`)
- Workload Identity addon enabled (`--enable-workload-identity`)
- The Workload Identity mutating admission webhook running in the cluster
- A federated credential configured on the Managed Identity in Entra ID

**VM Managed Identity (node-level)**  
The AKS node VM is assigned a Managed Identity. Pods request tokens from the IMDS endpoint (`169.254.169.254`) on the node. The CSI driver uses `useVMManagedIdentity: true` and the identity's `clientId`. No webhook required.

---

## What happened

The Workload Identity addon was enabled via `az aks update --enable-workload-identity --enable-oidc-issuer`. The addon installed the OIDC issuer and created the necessary Entra ID configuration, but the mutating admission webhook pod was not deployed to the cluster.

Without the webhook, pod specs are not mutated to inject the projected service account token volume. The CSI driver cannot obtain an Azure identity token for the pod, and Key Vault access fails silently — the `SecretProviderClass` mounts but returns no secrets.

Debugging confirmed the webhook was absent. Enabling the addon via `az aks update` is not sufficient; the webhook must be pre-installed or the cluster must be provisioned with the addon enabled from creation.

Given the single-node CPU constraint, adding the webhook retroactively would have required additional pods and a rolling restart with insufficient headroom.

---

## Decision

Disable the Workload Identity addon (`az aks update --disable-workload-identity --disable-oidc-issuer`) and use VM Managed Identity instead.

`SecretProviderClass` configuration:

```yaml
parameters:
  useVMManagedIdentity: "true"
  userAssignedIdentityID: "<managed-identity-client-id>"
  keyvaultName: daiberia-fleetops-kv
  tenantId: "<tenant-id>"
```

The Managed Identity (`daiberia-fleetops-id`) has `Key Vault Secrets User` role on the Key Vault, assigned by Terraform. No federated credential or webhook required.

---

## Consequences

- CSI Secrets Store works correctly. `SecretProviderClass` mounts all three secrets and generates the `fleetops-secrets` Kubernetes Secret consumed by fleet-api and telemetry-worker.
- VM Managed Identity is node-scoped, not pod-scoped. Any pod on the node can request a token for this identity. This is a weaker isolation model than Workload Identity. Accepted for this environment — the cluster has a single node and all workloads are part of the same project.
- If the project were extended to a multi-tenant cluster (multiple customer workloads), Workload Identity would be the correct approach. The migration path is: provision a new cluster with the addon enabled from creation, configure federated credentials per ServiceAccount, update the `SecretProviderClass` parameters.
- Disabling Workload Identity freed 2 pod slots on the node (the addon's webhook pods). This contributed to easing the pod pressure that existed before the CNI Overlay migration.
