# Phase 1: Requirements Specification

**Status:** Draft for review  
**Project:** Cloud-Native Application Deployment Platform  
**Last updated:** 2026-09-23  
**Scope:** Requirements only. No application or infrastructure implementation is included in this phase.

## 1. Problem

A developer needs a repeatable, reviewable way to build, package, deploy, and operate a containerized backend service on AWS. The project will demonstrate how application delivery, infrastructure provisioning, GitOps, security, observability, and failure recovery fit together.

The project is a learning and portfolio demonstrator. It is not a production service and has no production users or availability commitment.

## 2. Goals

- Build one small HTTP backend with PostgreSQL and Redis integrations.
- Provision its AWS network and EKS environment with Terraform.
- Build and store container images in ECR.
- Use GitHub Actions for review and build automation.
- Use Helm for Kubernetes packaging and Argo CD for GitOps delivery.
- Make health, readiness, deployment state, and operational failures observable.
- Practice failure diagnosis and recovery with documented, repeatable scenarios.
- Keep the work reviewable through feature branches, tests, pull requests, and documentation.
- Make only claims that are supported by artifacts and verification from this project.

## 3. Users and stakeholders

| User | Need |
|---|---|
| Project developer | Small, clear tasks; local feedback before AWS; safe Git and CI practices |
| Platform operator (the project owner) | Reproducible infrastructure, controlled deployments, useful runbooks, and cost visibility |
| API consumer (a test client) | A stable HTTP contract, clear errors, and health/readiness endpoints |
| Reviewer or interviewer | Understandable architecture, evidence for decisions, and honest limits on what was implemented |

## 4. Product requirements

### 4.1 Application

- The service shall expose a documented versioned HTTP API. The domain and first business operation are **open decisions** for review.
- The service shall expose separate liveness and readiness endpoints.
- Readiness shall report whether required dependencies are usable; liveness shall not depend on PostgreSQL or Redis.
- The service shall read configuration from its environment and shall not require credentials in source control.
- PostgreSQL shall provide persistent application data for the chosen demonstration operation.
- Redis shall be used for one documented, testable capability. Its role (cache, rate limit, or another use) is an **open decision**.
- Responses shall use consistent status codes and error shapes.
- Logs shall be structured and include enough context to investigate a request without logging credentials or sensitive payloads.
- Automated tests shall cover the API contract, dependency behavior, and error paths.

### 4.2 Deployment and infrastructure

- Infrastructure shall be defined in Terraform and separated into understandable modules where reuse or ownership boundaries justify them.
- The AWS network shall separate public ingress from private workloads and use multiple Availability Zones where supported by the selected design.
- EKS worker workloads shall run in private subnets. Public access shall enter through an AWS load balancer.
- Container images shall be tagged immutably for releases and stored in ECR.
- Kubernetes resources shall be packaged with Helm and include namespace, deployment, service, configuration references, resource requests/limits, and health probes.
- PostgreSQL and Redis hosting choices (managed AWS services or in-cluster) shall be decided in Phase 2 after architecture and cost comparison.
- GitHub Actions shall validate and test changes before any image publication or deployment.
- AWS access from GitHub Actions should use short-lived federation (OIDC) with least-privilege IAM rather than long-lived AWS access keys.
- Argo CD shall reconcile a reviewed desired state from Git.
- AWS changes shall require a reviewed Terraform plan. No production-like apply shall be run without explaining expected resources, cost, and teardown.

### 4.3 Deployment flow

The intended flow is:

1. A developer pushes a feature branch and opens a pull request.
2. GitHub Actions runs formatting, static checks, and tests.
3. An approved change to the application produces a versioned container image.
4. The image is pushed to ECR only after the required checks pass.
5. A reviewed Git change updates the desired image/chart configuration.
6. Argo CD reconciles that desired state to EKS.
7. Health checks and deployment status confirm whether the rollout succeeded.

The exact repository split for application source and GitOps configuration is an **open decision** for Phase 2.

### 4.4 Operations and observability

- Operators shall be able to determine whether the API is reachable and ready.
- Logs and metrics shall make request volume, error rate, latency, pod health, CPU, memory, and dependency health inspectable.
- Alerts and dashboards shall be added only when their signals and response actions are defined.
- Runbooks shall describe routine deployment, rollback, incident diagnosis, and recovery.
- Measurements such as p50/p95/p99 latency shall be generated by a repeatable test and reported with its workload and environment; they shall not be presented as production measurements.

## 5. Quality requirements

### Availability and recovery

- This is a non-production lab; no external SLA is promised.
- The design should tolerate one application pod becoming unhealthy without requiring a manual restart, subject to the selected replica and scheduling design.
- Failed deployments shall be detectable and recoverable through rollout rollback or GitOps reconciliation.
- Loss of PostgreSQL or Redis shall result in clear degraded behavior and actionable logs; the service shall not claim readiness when a required dependency is unavailable.
- Backup and recovery expectations for persistent database data must be defined before any shared or valuable data is stored.

### Security and privacy

- The GitHub repository is currently **public**. All committed source, documentation, configuration examples, and Git history are public.
- No credentials, private keys, real account identifiers, customer data, or personal data may be committed.
- Local environment files, Terraform state, credential files, and generated data shall be excluded by `.gitignore`; this is a safety net, not a secret detector.
- Example configuration shall use clearly fake placeholders and shall not contain real endpoints with embedded credentials or tokens.
- Secrets shall be injected at runtime from an appropriate secret store. The Phase 2 design shall select and document the mechanism.
- Container processes shall run as non-root where supported. IAM, Kubernetes RBAC, network rules, and image/dependency scanning shall follow least privilege.
- If a secret is accidentally committed, it must be rotated/revoked; deleting the file in a later commit does not remove it from public Git history.

### Scalability and performance

- The application shall be stateless between requests except for state held in PostgreSQL/Redis.
- The design shall permit changing pod replica count without changing the application.
- Horizontal scaling behavior shall be tested before any scale claim is made.
- Performance goals and load profiles are **open decisions**; latency or throughput targets must be agreed before performance testing.

### Cost

- The project shall be treated as a cost-controlled learning environment.
- Region, cluster sizing, NAT strategy, database hosting, retention, and teardown process must be costed before Terraform apply.
- The operator shall review cost estimates and explicitly choose when to provision and destroy lab resources.
- No cost amount is asserted in this requirements draft.

## 6. Failure scenarios to verify

The project shall include guided reproduction and recovery for at least:

- Invalid configuration or missing required environment variable
- PostgreSQL unavailable or slow
- Redis unavailable
- Container exits or enters CrashLoopBackOff
- Invalid image reference resulting in ImagePullBackOff
- Readiness/liveness probe misconfiguration
- Service selector or target port mismatch
- Failed Kubernetes rollout and rollback
- GitHub Actions check failure
- Terraform validation/plan failure
- Argo CD drift and reconciliation
- Unauthorized cluster or AWS access

Each exercise shall state symptoms, diagnostic commands, expected evidence, recovery, and cleanup. During the failure lab, the learner should diagnose before seeing the solution.

## 7. Acceptance criteria for Phase 1

Phase 1 is ready to close when the project owner has reviewed and agreed on:

- The demonstration service’s domain and first API operation
- The purpose assigned to Redis
- Database and Redis hosting direction (or the criteria for choosing in Phase 2)
- Development AWS region and cost ceiling/process
- Repository visibility expectations and secret handling
- Availability, recovery, and performance goals appropriate to a learning lab
- What counts as a verified outcome for each later phase

No AWS resources or application code are required to accept this specification.

## 8. Assumptions and decisions to confirm

These are proposals, not verified facts or commitments:

1. **Workload:** one small, stateless HTTP API is the first service.
2. **Audience:** this is a portfolio/lab project, not a service for real customers.
3. **Data:** only synthetic test data will be used.
4. **AWS environment:** a single AWS account and region will be used for the lab; the region is not selected.
5. **Database/cache hosting:** managed versus in-cluster PostgreSQL and Redis remains undecided until architecture and cost review.
6. **Repository visibility:** the current repository is public; source and all Git history are therefore public.
7. **Cost control:** no AWS resources will be provisioned until the planned resources, expected cost, and teardown are reviewed.

## 9. Out of scope for this project baseline

- Production service-level commitments or claims of real production use
- Real customer or personal data
- Multi-region disaster recovery
- Automatic production deployment without review
- Unmeasured performance, availability, or cost claims
- Application domain features until the domain decision in Section 8 is confirmed

## 10. Review checkpoint

Please review this draft and reply with:
- the application domain / first API operation (or approve a small task-tracking API),
- Redis's role (or approve cache),
- your preferred AWS region and a monthly lab cost ceiling (or ask to compare options in Phase 2),
- whether the repository should remain public.

Work stops here until these requirements are reviewed.