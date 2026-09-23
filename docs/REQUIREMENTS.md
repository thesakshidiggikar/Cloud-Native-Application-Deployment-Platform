# Requirements

## Problem and users

Teams and learners need a repeatable path from application change to observable Kubernetes deployment. The project exposes a small task API as a realistic workload for practicing cloud networking, containers, infrastructure as code, GitOps, data dependencies, operations and failure diagnosis.

Primary users are developers deploying the API, platform engineers operating the cluster, and learners reviewing each design decision. No customer or regulated data is in scope.

## Functional requirements

- Create, list, retrieve, update, and delete tasks with validation and stable JSON schemas.
- PostgreSQL is the durable source of truth and migrations are versioned.
- Redis caches reads with bounded TTL and invalidates changed task/list keys; a Redis outage must not lose data or block API writes.
- Expose separate process liveness and dependency readiness endpoints.
- Produce request-correlated structured logs without logging payloads or secrets.
- Build locally with Docker Compose; deploy through immutable ECR artifacts, Helm and Argo CD.

## Infrastructure and deployment requirements

- Terraform-managed VPC across multiple AZs with public ingress, private EKS nodes, and isolated managed data subnets.
- EKS nodes, RDS, and Redis are not publicly reachable; API server public access is restricted to explicit operator CIDRs and has a private endpoint.
- ECR scans images on push and uses immutable release tags.
- GitHub Actions test, dependency audit, build, Terraform validation, Helm lint/render and secret scanning on pull requests. Tagged releases publish to ECR using OIDC, not static keys.
- Helm defines deployment, service, config, probes, resources, PDB, HPA and optional HTTPS ALB ingress. Argo CD reconciles declared Git state; migrations gate rollouts.
- AWS resource creation requires a reviewed cost-aware plan and explicit environment values. Repository CI never applies infrastructure.

## Availability, security, and scaling

- Two application replicas as baseline; readiness removes unready endpoints; PDB limits voluntary disruption; HPA has explicit min/max.
- PostgreSQL is required for readiness, Redis is optional. Data backup retention and a final snapshot are configured. Restore is an operator-tested runbook, not assumed.
- Non-root containers, read-only root filesystem, dropped Linux capabilities, resource bounds, least-privilege IAM, HTTPS ingress, encrypted storage, Redis TLS, private DB/cache, secret-manager injection, immutable tags and dependency/image scanning.
- Scale app replicas and node group only within configured bounds; manage DB pool pressure explicitly.

## Observability and failure scenarios

Observe HTTP status/latency/request IDs, pod health/restarts/CPU/memory, HPA state, ALB target health, PostgreSQL CPU/storage/connections, Redis CPU/memory/evictions, Argo sync status, and release/migration events. CloudWatch alerts cover RDS CPU/storage and Redis engine CPU; notification routing is an environment setup step.

Failure exercises cover bad image/probe/service selector, process crash, DB and Redis outages, migration failure, GitHub check failure, Terraform validation failure, Argo drift, slow DB and bounded concurrency. Execute only in local/disposable environments.

## Success criteria

- Unit suite passes without AWS using SQLite and fake Redis.
- Compose API and migration start locally; CRUD and health behavior verified when Docker is available.
- CI successfully validates Python, dependencies, image build, Terraform and Helm; secret scan passes.
- A deliberate lab deployment can be diagnosed/recovered from Git desired state.
- Cloud deployment/availability/security/performance claims require actual evidence collected by the project owner; no results are invented in documentation.
