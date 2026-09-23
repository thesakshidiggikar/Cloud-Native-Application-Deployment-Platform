# Security model

## Secrets and public repository

This repository is public. `.gitignore` prevents common local credential/config paths from new commits, but it does **not** hide tracked files or erase Git history. Never place real keys, passwords, account-specific private URLs, kubeconfigs, database dumps, tfstate, tfplan, `.env`, or `terraform.tfvars` in a commit. Use AWS Secrets Manager plus External Secrets Operator for runtime values and GitHub OIDC for CI. Rotate/revoke any credential that is ever committed; deleting a file is not remediation.

The only tracked env file is `.env.example` with fake local-only Compose values. It is not a production credential.

## Identity

- CI requests short-lived AWS credentials with GitHub OIDC. Restrict role trust to this repo and version tag refs; scope ECR writes to the one repository.
- Use distinct IAM roles for AWS Load Balancer Controller and ESO; grant only required actions/resources.
- Use EKS access entries/RBAC for human access; do not give the application pod cluster-admin.
- App service account does not automount a Kubernetes API token by default.

## Network and data

- EKS worker nodes, RDS, Redis are private. Database/cache SG ingress is limited to the EKS node group SG.
- EKS public endpoint CIDRs must be explicit and must never be `0.0.0.0/0`.
- RDS storage and ElastiCache at-rest encryption enabled; Redis transit encryption enabled. TLS certificate validation must remain enabled in clients.
- ALB uses HTTPS and ACM certificate when ingress is enabled. Supply the real host/cert in ignored environment-specific values.
- Use least-privilege state bucket access, encryption, versioning, and locking. Terraform state can contain sensitive outputs and must never be public or committed.

## Workload and supply chain

Container runs non-root with read-only root filesystem, dropped Linux capabilities, resource bounds, and seccomp RuntimeDefault. Dependencies are pinned and CI uses pip-audit. ECR tag immutability and scan-on-push are enabled. CI secret scanning is included. Review action versions and supply-chain policy before production; branch protection and required status checks must be configured in repository settings.

## Incident response for secret exposure

Revoke/rotate the credential at its source, inspect audit logs for use, update Secrets Manager/GitHub settings, and check Git history and forks/caches. Notify affected owners as policy requires. Purge history only after rotation and with coordinated repo-owner action; history rewrite does not replace rotation.

### Cluster bootstrap identity

Terraform adds the identity that creates the cluster as an EKS administrator so the owner can bootstrap access and add-ons. This is a bootstrap convenience and not an application permission. Before a shared/production rollout, create named operator access entries with the required scoped EKS access policies, verify access, then disable cluster-creator admin and review the resulting Terraform plan.
