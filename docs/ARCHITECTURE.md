# Phase 2: Reference Architecture

**Status:** Draft for review  
**Project:** Cloud-Native Application Deployment Platform  
**Scope:** Architecture only. No AWS resources are created by this document.

## 1. Goals

- Keep API Pods and worker nodes private while accepting HTTP(S) through an internet-facing ALB.
- Separate application, database, and cache network access.
- Deliver changes through reviewed Git commits and Argo CD reconciliation.
- Leave account-specific identifiers, region, CIDRs, and domain details as deployment inputs.
- Support a cost-aware lab mode while documenting its availability tradeoffs.

## 2. Proposed workload

For the first demonstrator, this document proposes a small task-tracking API. PostgreSQL is the durable store. Redis is a short-lived cache for eligible task reads, invalidated on writes. The API exposes liveness, readiness, and versioned task endpoints. These are provisional choices pending review of Phase 1.

## 3. AWS architecture

The VPC spans at least two Availability Zones. Each AZ has a public subnet and private application subnet. EKS managed EC2 node groups run in private application subnets. RDS PostgreSQL and ElastiCache Redis use private data subnets with no direct internet route.

An internet-facing ALB lives in the public subnets. The AWS Load Balancer Controller reconciles Kubernetes Ingress resources with ALB listeners and targets. The ALB DNS name can be used for the initial lab; a custom domain and ACM certificate can be added later.

| Zone | Resources | Route/access intent |
|---|---|---|
| Public subnets, at least two AZs | ALB; optional NAT Gateway(s) | ALB routes through an Internet Gateway. No application nodes. |
| Private application subnets, at least two AZs | EKS managed nodes and Pods | No unsolicited inbound internet path. Egress through selected NAT or VPC endpoints. |
| Private data subnets, at least two AZs | RDS PostgreSQL, ElastiCache Redis | No public IP or public route. Accept only application-originated database/cache traffic. |
| EKS control plane | AWS-managed Kubernetes API | Private access for in-VPC clients. If operator public access is enabled, restrict it to an explicitly supplied CIDR. |

VPC CIDRs must be checked for overlap with existing networks before apply. Subnets need the Kubernetes load-balancer role tags so the controller can discover public and internal subnets.

### Security group intent

- ALB: accept HTTPS from clients; redirect HTTP to HTTPS if HTTP is enabled; forward only to the application target port.
- Nodes/Pods: allow application traffic from the ALB path and required cluster/node communications; no public node-port ingress.
- PostgreSQL: allow its database port only from the application workload.
- Redis: allow its cache port only from the application workload.
- Cluster API: allow required node/control-plane communications. Operator access must use a private network path or a tightly scoped public endpoint CIDR.

Implementation must specify exact ports, rules, and the workload security identity used for source rules.

### Egress and cost modes

Private IPv4 subnets require an egress path for AWS and external endpoints. The two choices are:

1. **Lab mode:** one shared NAT Gateway, plus VPC endpoints where useful. This lowers NAT hourly cost but creates cross-AZ traffic and a single-AZ egress dependency.
2. **Higher availability mode:** one NAT Gateway per AZ, with each private subnet routed through its local NAT. This reduces cross-AZ dependency and transfer but costs more.

Terraform will require an explicit choice. The cost estimate must be reviewed before apply. Data subnets remain isolated from general internet egress.

## 4. Request flow

1. A client resolves the ALB DNS name or later configured domain.
2. The public ALB terminates TLS and applies host/path routing.
3. The AWS Load Balancer Controller keeps ALB configuration aligned with Kubernetes Ingress.
4. The ALB forwards to a target in the EKS application subnets.
5. A Kubernetes Service selects ready API Pods.
6. The API uses PostgreSQL for durable task data.
7. Eligible reads may use Redis and fall back to PostgreSQL on cache miss.
8. The response returns through Service and ALB to the client.

~~~mermaid
flowchart LR
    U[API client] -->|HTTPS| ALB[Public Application Load Balancer]
    ALB --> ING[Kubernetes Ingress]
    ING --> SVC[ClusterIP Service]
    SVC --> API[Ready API Pod]
    API -->|SQL| PG[(Private PostgreSQL)]
    API -->|cache read/write| R[(Private Redis)]
    API -. miss or unavailable .-> PG
~~~

## 5. Deployment and GitOps flow

1. Developer creates a feature branch and opens a pull request.
2. GitHub Actions runs formatting, static checks, and tests that need no AWS credentials.
3. After review and merge, the build job creates and scans an image.
4. The pipeline uses GitHub OIDC to assume a narrowly scoped AWS role and publish to ECR.
5. The pipeline proposes a Git change pinning the deployment to the image digest.
6. Argo CD, running in EKS, reads the desired state from Git and applies the Helm release.
7. Kubernetes schedules Pods and pulls the image from ECR.
8. Readiness checks control traffic, and Argo CD/Kubernetes report rollout status.

The initial proposal keeps application and deployment configuration in this repository under app/ and deploy/. A separate GitOps repository can be introduced later if access separation or independent release cadence requires it.

~~~mermaid
flowchart LR
    DEV[Developer] --> PR[Feature branch and pull request]
    PR --> CI[GitHub Actions checks and tests]
    CI --> BUILD[Build and scan image]
    BUILD --> OIDC[Short-lived AWS role via OIDC]
    OIDC --> ECR[(Amazon ECR)]
    BUILD --> CHANGE[Reviewed image digest change in Git]
    CHANGE --> ARGO[Argo CD pulls desired state]
    ARGO --> EKS[Amazon EKS applies Helm release]
    EKS --> POD[Pods pull image from ECR]
~~~

## 6. Identity, secrets, and trust boundaries

- GitHub Actions receives short-lived AWS credentials through OIDC. The IAM trust policy must be limited to this repository and intended branch/environment.
- Use separate roles/policies for infrastructure provisioning, image publication, and in-cluster workload access.
- Workloads use IAM Roles for Service Accounts or EKS Pod Identity with only required permissions.
- Store database credentials outside Git, preferably in AWS Secrets Manager. Helm values contain references, never secret values.
- Terraform state can contain sensitive infrastructure metadata. It must be remote, encrypted, access-controlled, and locked before team use; never commit it.
- Because this repository is public, every tracked file and its Git history are public. The .gitignore only guards untracked local files.
- If a secret is committed, rotate/revoke it; deleting it in a later commit does not remove it from public history.

## 7. Data and dependencies

- PostgreSQL is the durable source of truth. Choose backup retention, recovery point, and recovery time expectations before storing valuable data.
- Redis is an optimization, not the source of truth. Cache failure must not lose task data. API degraded behavior must be defined and tested.
- RDS and ElastiCache use private subnet groups and security-group references, not public endpoints.
- TLS in transit, encryption at rest, maintenance, backup retention, and deletion protection must be explicit settings appropriate to a disposable lab versus retained environment.

## 8. Availability, scaling, and observability

- ALB subnets and EKS managed node groups span at least two AZs.
- The availability profile uses at least two API replicas and spreads them across nodes/AZs where capacity permits.
- A single lab NAT Gateway is a documented availability tradeoff; per-AZ NAT is the higher availability option.
- Database failover and Redis replication depend on selected service tiers and cost profile; managed services alone do not imply those properties.
- CloudWatch collects workload logs and infrastructure signals. Application metrics cover request count, errors, latency, and dependency state.
- Alarm thresholds require measured baselines and a defined operator action.
- HPA and database connection limits are set after resource and load tests.

## 9. Failure and recovery paths

| Failure | Expected signal | Recovery direction |
|---|---|---|
| API Pod exits | Pod status/restart and readiness change | Inspect events/logs; verify replacement Pods and rollout |
| Bad image reference | ImagePullBackOff | Confirm tag/digest and ECR access; restore last good digest |
| Probe or Service mismatch | No ready endpoints or unhealthy ALB target | Inspect probes, labels, ports, Ingress target configuration |
| PostgreSQL unavailable | Readiness/dependency errors and RDS metrics | Check events, security groups, connection limits, recovery path |
| Redis unavailable | Cache errors and degraded metrics | Check service/network; serve uncached reads if agreed contract allows |
| GitOps drift | Argo CD OutOfSync | Review diff; sync desired Git state or revert unwanted change |
| OIDC role assumption fails | GitHub job access denied | Check repository/ref/environment claims and role policy; do not add a long-lived key |
| Terraform plan fails or drifts | Validation/plan error or unexpected diff | Stop before apply; inspect provider, state, plan, and resource ownership |

## 10. Deployment-time inputs

These belong in local ignored configuration, GitHub environment settings, or AWS setup—not committed values:

- AWS account and region
- Terraform backend and locking configuration
- VPC CIDR and existing-network overlap constraints
- Operator CIDR or private access path for EKS management
- NAT mode and lab cost ceiling
- GitHub OIDC role setup
- Optional domain and ACM certificate
- Secret store and KMS configuration
- Database/cache sizing, backups, and deletion-protection choices

Implementation will use typed variables with safe examples and validation. It will stop with a clear error when required inputs are missing or unsafe. AWS credentials will come from the operator's local profile or federation at deployment time, never repository files.

## 11. Decisions to review

1. Approve or change the proposed task API and Redis read-cache role.
2. Choose one NAT for lab mode or per-AZ NAT after cost estimation.
3. Confirm managed RDS and ElastiCache for the reference deployment.
4. Keep app and GitOps configuration in one repository initially, or split it.
5. Select AWS region, management access path, and lab cost limit before Terraform.
6. Decide the domain/TLS approach; the ALB DNS name is enough for the initial lab.

## 12. References

- [Amazon EKS VPC and subnet best practices](https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html)
- [Amazon EKS VPC and subnet requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)
- [Amazon EKS load balancing best practices](https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html)
- [AWS IAM: Create a role for OIDC federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)

This is a design proposal only. It does not mean AWS resources were created or tested.
