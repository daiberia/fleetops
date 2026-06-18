# ADR-004 — telemetry-worker shared model dependency

**Date:** 2025  
**Status:** Deferred (accepted technical debt)

---

## Context

`telemetry-worker` writes telemetry events and alerts to PostgreSQL using the same SQLAlchemy models defined in `fleet-api`. Rather than duplicating the model definitions, the worker imports them directly from `fleet-api/app/models`.

This works at runtime because the `telemetry-worker` Dockerfile copies the `fleet-api/app/` directory into the worker image at build time:

```dockerfile
# telemetry-worker/Dockerfile
COPY services/fleet-api/app/ /app/fleet_api/app/
COPY services/telemetry-worker/worker/ /app/worker/
```

The build context must be the monorepo root (not `services/telemetry-worker/`) for this `COPY` instruction to resolve correctly. The CI pipeline uses:

```bash
docker build -f services/telemetry-worker/Dockerfile .
```

---

## Why this exists

The two services were developed sequentially, not in parallel. When `telemetry-worker` was built, the model definitions in `fleet-api` already existed and were correct. Duplicating them would have introduced drift risk. Importing them was the pragmatic short-term choice.

---

## Why this is wrong

- `telemetry-worker` has an implicit compile-time dependency on `fleet-api`. A change to `fleet-api/app/models.py` silently affects the worker's build.
- The dependency is invisible to anyone reading the worker's `requirements.txt` or `worker/` directory — it only becomes apparent when reading the Dockerfile.
- The Dockerfile is tightly coupled to the monorepo layout. Any restructuring of `services/` breaks the build.
- It prevents `telemetry-worker` from ever being extracted into a separate repository without first resolving the dependency.

---

## Correct solution

Extract shared database models into a `shared/` package at the monorepo root:

```
fleetops/
├── shared/
│   ├── __init__.py
│   ├── models.py       # SQLAlchemy models
│   └── database.py     # engine and session factory
├── services/
│   ├── fleet-api/
│   └── telemetry-worker/
```

Both services install `shared` as a local package dependency. Each Dockerfile copies only its own service directory plus `shared/`:

```dockerfile
COPY shared/ /app/shared/
COPY services/fleet-api/ /app/
```

This would also require updating the CI `sed`/`grep` path filter and the Trivy scan context.

---

## Decision

Deferred. The current approach works correctly and the monorepo layout is stable for the duration of FleetOps v1. The refactor adds no observable value to the running system and would require coordinated changes across both services, both Dockerfiles, both CI workflows, and the gitops Helm charts.

This will be addressed in v2 if `telemetry-worker` needs to evolve independently of `fleet-api`, or if a third service needs access to the shared models.

---

## Consequences

- Both CI workflows must use the monorepo root as the Docker build context. This is enforced and documented.
- Any developer working on `telemetry-worker` must be aware that `fleet-api/app/models.py` is a build-time dependency. This ADR is the documentation for that constraint.
- `fleet-api` model changes should be tested against `telemetry-worker` before merging. There are no automated cross-service tests enforcing this currently.
