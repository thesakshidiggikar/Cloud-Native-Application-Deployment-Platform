# Deployment guide

This guide deploys only after account details, budget, IAM ownership, and a reviewed Terraform plan are available. No workflow runs `terraform apply` automatically.

## 1. Local preflight

From `app/`, configure ignored `.env`, start Compose, create/read/update/delete a task, inspect logs, and run `python -m pytest -q`. Compose ports bind to `127.0.0.1`.

## 2. Terraform preflight

Install Terraform 1.11.1+ and AWS CLI v2. Authenticate with AWS IAM Identity Center or another short-lived profile. Bootstrap an encrypted, versioned, private S3 state bucket with restricted access and locking separately. Copy `backend.hcl.example` to ignored `backend.hcl`; copy `terraform.tfvars.example` to ignored `terraform.tfvars`, then set region and a trusted admin IPv4 CIDR.

~~~powershell
cd infra/terraform
terraform fmt -check -recursive
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=terraform.tfplan
terraform show terraform.tfplan
~~~

Expected resources: VPC with public/private/database subnets in two AZs; NAT gateway(s); EKS control plane/private nodes; RDS PostgreSQL; encrypted-in-transit Redis; ECR; CloudWatch alarms. Review region availability, CIDR overlap, public API CIDRs, instance availability, retention/deletion protection, and charges. A single NAT and single-AZ RDS/cache reduce lab cost but add failure domains. Production needs reviewed multi-AZ/backup/restore sizing. Do not apply a plan you cannot explain.

After review, save the plan output and apply only that reviewed plan in the intended account. Record actual charges privately; do not add account data to public Git.

## 3. Cluster add-ons and runtime secrets

Configure `kubectl` for the returned cluster. Install AWS Load Balancer Controller with its dedicated least-privilege role. Install Argo CD and External Secrets Operator (ESO) using maintained, verified charts and separate IAM roles. Configure ESO to read an environment-specific Secrets Manager object containing exactly `APP_DATABASE_URL` and `APP_REDIS_URL`. Construct the database URL from the RDS managed master secret in Secrets Manager. Redis uses `rediss://<private-endpoint>:6379/0` because transit encryption is enabled. Keep URLs and passwords in Secrets Manager only.

Create an ExternalSecret in the target namespace mapping those properties to Kubernetes Secret `devopshere-runtime`. Verify its existence without printing data. The Helm chart references it by name.

## 4. ECR publishing with GitHub OIDC

Create an IAM role whose trust policy requires `aud=sts.amazonaws.com` and restricts `sub` to this repository and `ref:refs/tags/v*`. Grant only ECR authorization-token permission and push/upload actions scoped to this ECR repository. Set GitHub repository variables `AWS_ROLE_TO_ASSUME`, `AWS_REGION`, and `ECR_REPOSITORY`. Do not set AWS access-key secrets. Push a semantic release tag, then verify the immutable tag and digest in ECR.

## 5. GitOps rollout

Set chart `image.repository` to the ECR output and `image.tag` to the published immutable release. Store HTTPS host and ACM certificate ARN in an ignored environment-specific values file; ensure two public subnets have external load-balancer tags. Apply/track `deploy/argocd/application.yaml` with Argo CD only after those values are correct. The PreSync migration Job applies Alembic migrations before rollout. Verify Argo health, `kubectl rollout status`, ALB target health, `/health/ready`, API smoke, and logs. Costs begin before traffic is routed.

## 6. Rollback and teardown

For app rollback, pin a previous immutable image tag in Git and let Argo sync; database downgrades are not automatic. Restore from a tested snapshot/PITR procedure if a schema rollback is unsafe. For full teardown, preserve required snapshots/export data, remove Argo workloads/add-ons, then Terraform resources in reviewed order. Confirm deletion protection and final snapshot identifiers; Terraform retains a final DB snapshot. Review NAT, EKS, RDS, Redis, load balancer, ECR, and CloudWatch charges before and after teardown.
## Inputs that must be supplied by the owner

Keep these in ignored environment files or GitHub settings, never in tracked sources:

| Setting | Destination | Example shape only |
|---|---|---|
| AWS region and trusted EKS API CIDR | ignored `terraform.tfvars` | `us-east-1`, `203.0.113.10/32` (documentation range only) |
| S3 backend bucket/key/region | ignored `backend.hcl` | private, encrypted and versioned state bucket |
| GitHub OIDC role ARN / ECR repo / region | GitHub Actions repository variables | IAM role ARN, ECR repo name |
| DB/Redis runtime URLs | AWS Secrets Manager | `postgresql+psycopg://...`, `rediss://...` |
| DNS name and ACM certificate ARN | ignored Helm environment values | owned domain and matching regional cert |

The docs examples are placeholders, not endpoint values. Git ignore only prevents future local files matching the patterns from being staged; it cannot make a public repository private or retract a value already pushed. Use a secret manager, scan before every push, and rotate any exposed credential immediately.
