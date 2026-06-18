# Architecture — FleetOps

## Overview

FleetOps is a multi-tenant fleet management SaaS platform running on a single-node AKS cluster in Azure `francecentral`. The system is designed to demonstrate production-grade cloud-native patterns within a hard resource constraint: one `Standard_D2as_v4` node (2 vCPU / 8 GB RAM).

Every infrastructure resource is provisioned by Terraform. Every application change flows through GitHub Actions CI into ArgoCD GitOps — no manual `kubectl apply` in steady state.

---

## System diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Developer                                                      │
│  git push → daiberia/fleetops                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  GitHub Actions CI                                              │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────────────┐   │
│  │ lint + pytest│→ │ Trivy SAST  │→ │ build + push ACR      │   │
│  └──────────────┘  └─────────────┘  └──────────┬───────────┘   │
│                                                 │               │
│                                    update tag in fleetops-gitops│
└─────────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  daiberia/fleetops-gitops  (ArgoCD source of truth)             │
│  apps/fleet-api/values.yaml          tag: <commit-sha>          │
│  apps/telemetry-worker/values.yaml   tag: <commit-sha>          │
└────────────────────┬────────────────────────────────────────────┘
                     │  ArgoCD polls every 3 min
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  AKS  francecentral · Standard_D2as_v4 · 1 node                 │
│                                                                 │
│  namespace: fleetops                                            │
│  ┌─────────────────┐   ┌──────────────────┐                    │
│  │   fleet-api     │   │ telemetry-worker  │                    │
│  │   FastAPI       │   │ Python worker     │                    │
│  │   /metrics      │   │ 15s sim loop      │                    │
│  └────────┬────────┘   └────────┬─────────┘                    │
│           │                     │                               │
│           └──────────┬──────────┘                               │
│                      ▼                                          │
│            ┌─────────────────┐                                  │
│            │    postgres      │  StatefulSet · PVC 5Gi          │
│            │  PostgreSQL 15   │  priorityClass: system-critical  │
│            └─────────────────┘                                  │
│                                                                 │
│  namespace: ingress-nginx                                       │
│  ┌──────────────────────────────────────┐                       │
│  │  nginx ingress · cert-manager        │  Let's Encrypt TLS    │
│  │  externalTrafficPolicy: Local        │                       │
│  └──────────────────────────────────────┘                       │
│                                                                 │
│  namespace: argocd                                              │
│  ┌──────────────────┐                                           │
│  │  ArgoCD           │  pull-based CD · auto-heal               │
│  └──────────────────┘                                           │
│                                                                 │
│  namespace: monitoring                                          │
│  ┌──────────────┐  ┌─────────────┐                             │
│  │  Prometheus  │  │   Grafana   │  dashboard JSON in repo      │
│  └──────────────┘  └─────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
                     │
         ┌───────────┼────────────────┐
         ▼           ▼                ▼
┌──────────────┐ ┌──────────┐ ┌────────────────────────┐
│  Azure       │ │  Azure   │ │  Log Analytics          │
│  Key Vault   │ │   ACR    │ │  Workspace              │
│              │ │          │ │  + Microsoft Sentinel   │
│  3 secrets   │ │  images  │ │  3 KQL detection rules  │
└──────────────┘ └──────────┘ └────────────────────────┘
```

---

## Infrastructure (Terraform)

All Azure resources are provisioned from `infra/` in a single `terraform apply`. Modules are independent and called in dependency order from `main.tf`.

| Module | Resources |
|---|---|
| `networking` | VNet, subnets, NSGs |
| `identity` | Managed Identity, RBAC assignments (AcrPull, Key Vault Secrets User) |
| `acr` | Azure Container Registry (`daiberiafleetopsacr`) |
| `aks` | AKS cluster, node pool (`Standard_D2as_v4`), OMS agent addon |
| `keyvault` | Key Vault (`daiberia-fleetops-kv`), CSI access policy |
| `monitoring` | Log Analytics Workspace (`daiberia-fleetops-law`) |
| `sentinel` | Microsoft Sentinel, 3 scheduled KQL analytics rules |

Remote state lives in an Azure Blob Storage account (`daiberiatfstate`) in a separate resource group (`daiberia-tfstate-rg`) bootstrapped manually before first apply.

Terraform CI runs `plan` automatically on every PR and gates `apply` behind a manual approval using the `production` GitHub Environment. A dedicated service principal (`daiberia-fleetops-terraform-ci`) with least-privilege RBAC handles authentication.

---

## CI/CD pipeline

### Separation of concerns

| Stage | Tool | Trigger |
|---|---|---|
| Build, test, scan, push | GitHub Actions | `git push` to `daiberia/fleetops` |
| Deploy | ArgoCD | commit to `daiberia/fleetops-gitops` |

GitHub Actions never runs `kubectl` or `helm`. It only pushes images to ACR and updates `values.yaml` in the gitops repo. ArgoCD does the rest.

### CI steps (both services)

```
lint (flake8) → pytest → Trivy SAST → docker build + push ACR (tag=$SHA) → sed values.yaml + push gitops
```

- Test failures block the pipeline — no bypass.
- Trivy pinned to `v0.36.0`. Supply chain attack affected `@master` builds through March 2026.
- Image tag is always the commit SHA. No `latest`.
- `sed` pattern scoped to `^  tag:` to avoid false matches on other fields.
- A `grep` verification step confirms the tag was updated before committing to the gitops repo.

### ArgoCD

- Poll interval: 3 minutes (default).
- Auto-sync and self-heal enabled on all Applications.
- Any manual `kubectl` change to a managed resource is reverted on next sync.
- `postgres` is deliberately outside ArgoCD — see ADR-001.

---

## Application design

### fleet-api

FastAPI service. Provides the REST API consumed by the frontend (not in scope for this project) and by the telemetry-worker for shared model definitions.

**Multi-tenancy:** every authenticated request carries a JWT with `company_id`. All database queries filter on `company_id` at the SQL layer — not in application logic. Row isolation is enforced at the query level.

```python
# example — vehicles endpoint
db.query(Vehicle).filter(Vehicle.company_id == current_user.company_id)
```

**Endpoints:**
- `GET /health` — liveness/readiness, includes DB connectivity check
- `GET /metrics` — Prometheus metrics (prometheus-fastapi-instrumentator)
- `GET/POST /vehicles` — vehicle CRUD, scoped to tenant
- `POST /telemetry` — ingest telemetry event
- `GET /alerts` — alert listing, scoped to tenant

**Database migrations:** Alembic. Schema version is part of the image; migrations run as part of the deployment process.

### telemetry-worker

Autonomous Python worker. No HTTP interface, no ingress. Runs a simulation loop every 15 seconds generating GPS coordinates, speed, and fuel level for 5 vehicles across three routes:

- Madrid → Barcelona
- Sevilla → Málaga
- Bilbao → Madrid

Writes telemetry events directly to PostgreSQL and generates alert conditions (low fuel, speeding) to populate the alerts table for demo purposes.

**Known architectural debt:** the worker imports `fleet-api/app/models` directly. This is resolved at build time by copying the `fleet-api/app/` directory into the worker image. A `shared/` package is the correct long-term solution — tracked in ADR-004.

### PostgreSQL

StatefulSet with a 5Gi PVC. Runs outside ArgoCD with `priorityClassName: system-cluster-critical` to survive AKS control-plane evictions on cluster restart (see ADR-001 for the full incident).

Schema:

```sql
companies  (id, name, plan, created_at)
vehicles   (id, company_id, plate, model, status)
telemetry  (id, vehicle_id, lat, lon, speed, fuel, timestamp)
alerts     (id, vehicle_id, type, severity, message, resolved_at)
```

---

## Secrets management

No secrets in YAML manifests, environment files, container images, or Git history.

```
Azure Key Vault
    fleetops-db-password
    fleetops-db-url
    fleetops-jwt-secret
         │
         │  CSI Secrets Store driver
         │  VM Managed Identity (useVMManagedIdentity: true)
         ▼
    SecretProviderClass: fleetops-secrets
         │
         │  secretObjects block
         ▼
    Kubernetes Secret: fleetops-secrets  →  env vars in fleet-api and telemetry-worker pods
```

The Kubernetes Secret is generated and kept in sync by the CSI driver. It is never created or updated manually.

Access is granted via Managed Identity RBAC (`Key Vault Secrets User` role), provisioned by Terraform. No service principal passwords involved.

---

## Networking

External traffic enters through an Azure Load Balancer → ingress-nginx → service → pod.

`externalTrafficPolicy: Local` is required. With `Cluster` mode, the Azure LB health probe targets the node IP directly but the nodeport forwards traffic to a random node — the probe fails silently and external traffic is dropped.

TLS is terminated at the ingress. cert-manager handles certificate issuance and renewal via the `letsencrypt-prod` ClusterIssuer. Certificates are stored as Kubernetes Secrets and rotated automatically.

---

## Observability

### Metrics

Prometheus scrapes all targets on a 15-second interval. fleet-api exposes `/metrics` via `prometheus-fastapi-instrumentator`. Grafana reads from Prometheus as its sole datasource.

Dashboard `FleetOps — API Overview` (4 panels):
- API Request Rate (req/s)
- API Latency p95 (ms)
- Requests by endpoint
- 5xx Error Rate

Dashboard JSON is committed to `fleetops-gitops/grafana/dashboards/`. Grafana has no persistent volume — the dashboard is loaded from the repo on pod start.

`kube-prometheus-stack` was evaluated and rejected. At full deployment it generates ~10 pods including alertmanager, node-exporter, kube-state-metrics, and pushgateway. On a single D2as_v4 node already running ArgoCD, ingress-nginx, cert-manager, and the application stack, this was not viable. Independent lightweight charts (`prometheus-server` + `grafana`) provide equivalent functionality for this project's needs.

### Logs

Azure Monitor Agent (`ama-logs`, DaemonSet in `kube-system`) ships container logs from all namespaces to Log Analytics Workspace. All cluster components are covered without per-pod configuration.

### SecOps — Microsoft Sentinel

Three scheduled KQL analytics rules, each generating incidents automatically:

**Rule 1 — Brute force API**
```kql
ApiRequests
| where StatusCode == 401
| summarize count() by ClientIP, bin(TimeGenerated, 5m)
| where count_ > 20
```
Incident: `Possible brute force from <IP>`

**Rule 2 — Privilege escalation (Entra ID)**
```kql
AuditLogs
| where OperationName == "Add member to role"
| where TargetResources has "Global Administrator"
| where TimeGenerated !between (time(09:00)..time(18:00))
```
Incident: `Admin role assigned outside business hours`

**Rule 3 — kubectl exec in production**
```kql
KubeAuditAdminLogs
| where Verb == "exec"
| where ObjectRef has "fleet-api"
| where Namespace == "fleetops"
```
Incident: `Interactive exec into production pod`

---

## Resource sizing

All components sized to fit within 2 vCPU / 8 GB RAM on a single node.

| Component | CPU request | RAM request |
|---|---|---|
| fleet-api (1 replica) | 100m | 128Mi |
| telemetry-worker | 100m | 128Mi |
| postgres | 200m | 256Mi |
| ArgoCD (core only) | ~150m | ~300Mi |
| Prometheus | ~100m | ~400Mi |
| Grafana | ~50m | ~150Mi |
| ingress-nginx | ~50m | ~90Mi |
| cert-manager | ~20m | ~64Mi |
| kube-system (AKS reserved) | ~500m | ~1.5Gi |

Node observed CPU at steady state: ~1847m / 1900m allocatable.

Rolling update strategy on fleet-api: `maxSurge: 0, maxUnavailable: 1`. With the node near CPU capacity, a surge pod cannot be scheduled — this would deadlock the rollout indefinitely. See ADR-002.

---

## IAM

| Layer | Mechanism |
|---|---|
| Application authentication | Entra ID App Registration · JWT with `company_id` and `role` claims |
| Infra → ACR | Managed Identity · `AcrPull` role |
| Infra → Key Vault | Managed Identity · `Key Vault Secrets User` role |
| CI → Azure | Service Principal `daiberia-fleetops-terraform-ci` · `Contributor` on RGs |
| kubectl access | `--admin` flag (Azure RBAC OIDC does not propagate correctly for guest/EXT accounts) |

No secrets or passwords are stored in GitHub Actions beyond what is required for the Terraform SP. ACR and Key Vault access from the cluster uses Managed Identity exclusively.

---

## ADRs

Detailed records for non-obvious decisions:

- [ADR-001](adr/ADR-001-cni-overlay-migration.md) — CNI migration to Overlay and the quota incident
- [ADR-002](adr/ADR-002-rolling-update-maxsurge.md) — `maxSurge: 0` constraint on rolling updates
- [ADR-003](adr/ADR-003-vm-managed-identity.md) — VM Managed Identity vs Workload Identity
- [ADR-004](adr/ADR-004-telemetry-worker-shared-models.md) — telemetry-worker shared model dependency
