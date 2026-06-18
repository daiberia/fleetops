# ADR-002 — `maxSurge: 0` constraint on rolling updates

**Date:** 2025  
**Status:** Active

---

## Context

Kubernetes rolling updates work by default with `maxSurge: 1, maxUnavailable: 0` — meaning the scheduler brings up a new pod before terminating the old one. This requires enough free capacity on the node to run both pods simultaneously.

The FleetOps cluster runs on a single `Standard_D2as_v4` node with 1900m allocatable CPU. At steady state with all services running, observed CPU usage is approximately 1847m. There is not enough headroom to schedule a surge pod for fleet-api alongside the existing one.

---

## What happens without this fix

When a new image is pushed and ArgoCD triggers a rolling update with default settings:

1. Kubernetes tries to schedule the new pod.
2. The node has insufficient CPU — the new pod sits in `Pending`.
3. The old pod is not terminated (because `maxUnavailable: 0`).
4. The rollout is deadlocked indefinitely. ArgoCD shows the Application as `Progressing` with no resolution.

This was observed in production during the first post-CNI-recreation deploy.

---

## Decision

Set `maxSurge: 0, maxUnavailable: 1` in the fleet-api deployment rolling update strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
```

This terminates the old pod first, freeing its CPU allocation, and then schedules the new pod. There is a brief period (~5–10 seconds) where fleet-api has zero running replicas. This is acceptable for a portfolio/demo environment.

The configuration lives in `fleetops-gitops/apps/fleet-api/templates/deployment.yaml` and is managed by ArgoCD. It is not applied with `kubectl` directly.

---

## Consequences

- Rolling updates complete reliably without deadlocking.
- There is a short window of unavailability during each deploy. Acceptable given the single-node constraint.
- If a second node were ever added (requires quota expansion, not possible on Azure for Students), this constraint can be relaxed to `maxSurge: 1, maxUnavailable: 0` for true zero-downtime deploys.
- `telemetry-worker` is a single-replica background worker with no HTTP traffic — rolling update strategy is less critical but applies the same configuration for consistency.
