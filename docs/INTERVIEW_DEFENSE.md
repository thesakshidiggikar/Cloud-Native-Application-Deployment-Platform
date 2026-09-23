# Interview defense notes

Use this as a discussion guide after you have personally run the system. Avoid claiming production operation, high availability, security certification, or measured SLO/performance without evidence.

## Design decisions to defend

- PostgreSQL owns durable state; Redis is a cache so its outage does not lose data.
- Readiness checks critical durable dependency; liveness does not restart healthy processes due to temporary dependency failures.
- Private worker/data subnets reduce exposure; EKS public API ingress is operator-CIDR restricted.
- GitHub OIDC avoids long-lived CI credentials; ECR tags are immutable.
- Helm values describe deployment; Argo CD continuously reconciles that desired state.
- Terraform state is remote/private and is sensitive. Plans are reviewed before apply.
- Lab topology trades availability for cost (single NAT, single-AZ RDS, one Redis node). It must not be represented as HA production.
- Database migrations run as a pre-sync job; rollback requires schema compatibility analysis.

## Evidence to collect before resume claims

- CI run links showing tests, dependency audit, image build, Helm lint/render, Terraform validate and secret scan.
- Local Compose smoke test and CRUD/failure test outputs.
- If personally deployed: sanitized Terraform plan/apply evidence, `kubectl get nodes`, Argo health, ALB/TLS smoke, CloudWatch views, backup/restore drill and teardown.
- If performance is claimed: k6 output, exact scenario, region/environment, image/config versions, database sizing, cache state, sample duration, and p50/p95/p99.

Supported current claims are limited to repository artifacts and checks actually run. Cloud deployment and runtime metrics are not yet verified.
