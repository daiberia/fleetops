# FleetOps

Fleet management SaaS platform built to demonstrate production-grade cloud-native engineering on Azure. Multi-tenant API, simulated GPS telemetry, end-to-end GitOps, secrets management, observability stack, and SecOps with Microsoft Sentinel — all running on a single-node AKS cluster provisioned entirely with Terraform.

> Built by [Daiberia](https://github.com/daiberia) as a public portfolio project.

---

## What it does

FleetOps is a B2B SaaS platform for logistics companies to manage vehicle fleets. Two backend services run in Kubernetes:

- **fleet-api** — FastAPI REST API. Multi-tenant (JWT with `company_id`). CRUD for vehicles, telemetry ingestion, alert management. Exposes Prometheus metrics at `/metrics`.
- **telemetry-worker** — Python worker that simulates GPS/speed/fuel events for a fleet of 5 vehicles across three Spanish routes, writing to PostgreSQL every 15 seconds. Generates realistic alert conditions.

Both services share a PostgreSQL StatefulSet as their data store.

---

## Architecture

```
git push (daiberia/fleetops)
        │
        ▼
GitHub Actions CI
        ├── lint + pytest
        ├── Trivy SAST (blocks on critical CVEs)
        ├── docker build → push ACR (tag = $GITHUB_SHA)
        └── update image tag in daiberia/fleetops-gitops
                        │
                        ▼  ArgoCD polls fleetops-gitops
                ArgoCD detects values.yaml change
                        │
                        ▼
                helm template → kubectl apply → rolling update (0 downtime)
                auto-heal: any manual kubectl change → ArgoCD reverts it

AKS Cluster  francecentral · Standard_D2as_v4 · 1 node · 8 GB RAM
    fleetops       fleet-api · telemetry-worker · postgres StatefulSet
    argocd         GitOps controller
    monitoring     Prometheus · Grafana
    ingress-nginx  nginx ingress · cert-manager (Let's Encrypt TLS)
    cert-manager

Secrets: Azure Key Vault → CSI Secrets Store driver → K8s Secret (no plaintext anywhere)
Logs:    AMA agent → Log Analytics Workspace → Microsoft Sentinel (3 KQL detection rules)
```

Full architecture diagram and design decisions: [`docs/architecture.md`](docs/architecture.md)

---

## Stack

| Layer | Technology |
|---|---|
| Cloud | Azure (AKS, ACR, Key Vault, Log Analytics, Sentinel) |
| IaC | Terraform — modular, remote state in Azure Blob |
| Container orchestration | AKS (Kubernetes 1.35) |
| GitOps / CD | ArgoCD (pull-based, auto-heal) |
| Package management | Helm |
| CI | GitHub Actions |
| SAST | Trivy (pinned, blocks pipeline on critical CVEs) |
| API | Python 3.12 · FastAPI · SQLAlchemy · Alembic |
| Worker | Python 3.12 (async simulation loop) |
| Database | PostgreSQL 15 (StatefulSet, PVC 5 Gi) |
| Networking | ingress-nginx · cert-manager · Let's Encrypt |
| Secrets | Azure Key Vault · CSI Secrets Store · VM Managed Identity |
| Metrics | Prometheus · prometheus-fastapi-instrumentator |
| Dashboards | Grafana (dashboard persisted in repo as JSON) |
| Logging | Azure Monitor Agent → Log Analytics Workspace |
| SecOps | Microsoft Sentinel · 3 custom KQL scheduled rules |
| IAM | Entra ID app registration (JWT) · Managed Identity (infra) |

---

## Repository layout

```
fleetops/
├── infra/                  Terraform root + modules
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf         azurerm ~>3.110, azuread ~>2.53
│   ├── backend.tf          remote state → daiberiatfstate (Azure Blob)
│   └── modules/
│       ├── networking/     VNet, subnets, NSGs
│       ├── identity/       Managed Identity, RBAC assignments
│       ├── acr/            Azure Container Registry
│       ├── aks/            AKS cluster, node pool, OMS agent
│       ├── keyvault/       Key Vault, CSI access policy
│       ├── monitoring/     Log Analytics Workspace
│       └── sentinel/       Microsoft Sentinel, 3 KQL detection rules
├── services/
│   ├── fleet-api/          FastAPI app + Dockerfile
│   └── telemetry-worker/   Simulation worker + Dockerfile
├── .github/workflows/
│   ├── ci-fleet-api.yaml
│   ├── ci-telemetry-worker.yaml
│   └── ci-terraform.yaml   plan (auto) + apply (manual, gated)
└── docs/
    ├── architecture.md
    └── adr/                Architecture Decision Records
```

Helm charts and ArgoCD Applications live in the companion repo: [`daiberia/fleetops-gitops`](https://github.com/daiberia/fleetops-gitops)

---

## Infrastructure

Provisioned entirely with Terraform. Module dependency order:

```
networking → identity → acr → aks → keyvault → monitoring → sentinel
```

**CI/CD for infrastructure:** `.github/workflows/ci-terraform.yaml` runs `terraform plan` automatically on every PR and gates `terraform apply` behind a manual approval step using the `production` GitHub Environment. A dedicated service principal (`daiberia-fleetops-terraform-ci`) with least-privilege RBAC handles authentication — no personal credentials in CI.

One-time bootstrap before first `terraform init` (creates remote state backend):

```powershell
az group create -n daiberia-tfstate-rg -l francecentral
az storage account create --name daiberiatfstate `
  --resource-group daiberia-tfstate-rg --sku Standard_LRS
```

---

## CI pipeline

Both service pipelines follow the same structure:

```
lint (flake8) + pytest  →  Trivy SAST  →  docker build + push ACR  →  update image tag in fleetops-gitops
```

- Tests block the pipeline — no `|| true` bypasses.
- Trivy pinned to `v0.36.0` (supply chain attack affected `@master` builds through March 2026).
- Image tag is the commit SHA. ArgoCD detects the `values.yaml` change and rolls out.

---

## Secrets management

No secrets in YAML, environment files, or container images.

```
Azure Key Vault (daiberia-fleetops-kv)
    fleetops-db-password
    fleetops-db-url
    fleetops-jwt-secret
        │
        ▼  CSI Secrets Store driver (VM Managed Identity)
    SecretProviderClass fleetops-secrets  →  K8s Secret  →  env vars in pods
```

The K8s Secret is generated and rotated by the CSI driver. It is never created manually.

---

## Observability

**Metrics:** Prometheus scrapes fleet-api at `/metrics` (via `prometheus-fastapi-instrumentator`). Dashboard `FleetOps — API Overview` in Grafana shows request rate, p95 latency, requests by endpoint, and 5xx error rate. Dashboard JSON is committed to `fleetops-gitops/grafana/dashboards/` — survives Grafana restarts (no persistent volume).

**Logs:** Azure Monitor Agent (`ama-logs`) ships container logs from all namespaces to Log Analytics Workspace.

**SecOps — Microsoft Sentinel, 3 KQL detection rules:**

| Rule | Logic |
|---|---|
| Brute force API | >20 HTTP 401s from the same IP within 5 minutes |
| Privilege escalation | Global Administrator role assigned outside business hours |
| kubectl exec in prod | `exec` verb against any pod in the `fleetops` namespace |

---

## Multi-tenancy

JWT payload carries `company_id`. Every query filters at the SQL layer:

```python
# vehicles router — simplified
db.query(Vehicle).filter(Vehicle.company_id == current_user.company_id)
```

Row-level isolation is enforced in the database query, not in application logic.

---

## Running locally

The cluster runs on Azure. There is no local Docker or local Kubernetes setup — all container builds go through ACR Tasks:

```powershell
az acr build --registry daiberiafleetopsacr `
  --image fleet-api:local `
  --file services/fleet-api/Dockerfile .
```

To start the cluster after it has been stopped:

```powershell
az aks start --name daiberia-fleetops-aks --resource-group daiberia-fleetops-rg
# then run start-cluster.ps1 to scale kube-system components and fetch credentials
```

---

## Known constraints and design decisions

See [`docs/architecture.md`](docs/architecture.md) and [`docs/adr/`](docs/adr/) for full context. Key points:

- **Single D2as_v4 node (2 vCPU / 8 GB RAM)** — Azure for Students quota. Every component is sized to fit. `kube-prometheus-stack` was replaced with lightweight independent charts for this reason.
- **CNI Overlay** — migrated from kubenet after a quota incident during in-place CNI migration. Documents as ADR-001.
- **Rolling update strategy** — `maxSurge: 0, maxUnavailable: 1` on fleet-api. With the node at ~1847m/1900m CPU, a surge pod would deadlock the scheduler.
- **postgres outside ArgoCD** — StatefulSet runs with `priorityClassName: system-cluster-critical` to survive AKS control-plane pod evictions on restart. ArgoCD manages everything else.
- **VM Managed Identity over Workload Identity** — Workload Identity requires the mutating webhook pre-installed; the addon alone is insufficient. VM Managed Identity works without it and was the pragmatic choice for this environment.

---

## ADRs

| # | Decision |
|---|---|
| ADR-001 | CNI migration to Overlay and the quota incident |
| ADR-002 | `maxSurge: 0` constraint on rolling updates |
| ADR-003 | VM Managed Identity vs Workload Identity |
| ADR-004 | telemetry-worker shared model dependency (deferred refactor) |

---

## License

MIT
