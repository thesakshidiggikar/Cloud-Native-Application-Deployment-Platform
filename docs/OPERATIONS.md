# Operations guide

## Signals

- Liveness: `/health/live` says whether the process responds; it does not call dependencies.
- Readiness: `/health/ready` requires PostgreSQL and reports Redis as `ok`, `degraded`, or `disabled`.
- Each HTTP response includes `X-Request-ID`. Structured logs contain path, method, status and duration, but not request bodies, query values, cookies, or authorization headers.
- EKS installs the CloudWatch Observability add-on through Terraform for cluster/container telemetry. Terraform also creates RDS CPU/storage and Redis engine-CPU alarms. These alarms need notification routing (SNS/on-call destination) configured separately.

## Routine checks

Check Argo application sync/health; deployment rollout and ready replicas; pod restart counts; HPA metrics; ALB target health; CloudWatch application logs; RDS CPU/free storage/connections; Redis CPU/memory/evictions; and recent deploy/migration events. Never paste credential-bearing environment output into tickets or chat.

## Capacity and scaling

HPA scales on CPU/memory requests. Node group limits bound compute. Before increasing replicas, estimate peak connections as `replicas × SQLAlchemy pool size` and leave headroom for migrations/admin work. Observe RDS connections and latency before changing pool or HPA settings. Redis is a cache: check hit/miss and eviction signals before resizing. Load-test within a bounded duration and watch AWS costs.

## Backups and recovery

RDS automated backups have a configurable retention period and final snapshot protection. Schedule and document restore drills before production. Define RPO/RTO with stakeholders; this repo does not claim either. Redis can be recreated because durable records remain in PostgreSQL. Store recovery evidence and timestamps without publishing account identifiers or customer data.

## Release and rollback

Publish only immutable version tags. Update chart image tag through a reviewed Git change and wait for Argo sync and healthy targets. If application regression, revert the image tag and sync. Treat schema downgrade separately; prefer forward-fix unless a tested restore/rollback plan exists.

## Cost controls

Set AWS budgets/alerts externally before apply. NAT gateways, EKS control plane/nodes, RDS, Redis, ALB, NAT data processing, and CloudWatch ingestion are billable. Lab defaults favor one NAT and small/single-AZ managed data resources; production resilience increases cost. Review service-specific prices for the chosen account/region and tear down unused labs.
