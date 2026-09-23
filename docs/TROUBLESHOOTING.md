# Troubleshooting

## Compose API never becomes healthy

1. `docker compose ps` and `docker compose logs migrate postgres api`.
2. Confirm `.env` exists and contains only the local sample values.
3. Check Postgres health and migration job exit status; correct the migration issue before restarting API.
4. Check port 8000/5432/6379 conflicts; Compose binds only loopback.
5. Do not delete the database volume unless its data is disposable.

## Readiness returns 503

`/health/ready` reports dependency status. For PostgreSQL, inspect pod logs and DB connectivity/security group/secret key names. For Redis `degraded`, the API remains ready: inspect TLS URL and endpoint, but reads fall back to PostgreSQL. Never echo environment variables containing connection strings.

## Kubernetes pods Pending

Describe pod and inspect events. Check node capacity, resource requests, node group desired/max size, subnet IP capacity, taints/tolerations, and image pull policy. Do not raise max capacity without checking cost.

## CrashLoopBackOff

Inspect previous logs, exit code, events and startup/readiness probes. Verify image, command, required Secret existence/keys, DB URL shape, migrations and resource limits. Roll back the chart release/image if introduced by a new release; fix forward via Git.

## ImagePullBackOff

Check ECR repo/tag/digest, node or pod pull identity, network egress/endpoints, and image architecture. ECR tags are immutable; publish a new tag instead of trying to overwrite.

## ALB has no healthy targets

Verify AWS Load Balancer Controller status/permissions, ingress subnet discovery tags, HTTPS certificate/host, target type `ip`, service selector/endpoints, pod readiness, health path, and security-group rules. Avoid opening database/cache ports publicly.

## Argo CD OutOfSync or SyncFailed

Inspect diff and sync operation. Confirm target revision/path/chart syntax, image tag, required runtime Secret and namespace. Reconcile by fixing Git desired state, not by repeatedly editing live resources. A PreSync migration failure blocks app sync; inspect Job logs before retry.

## Terraform plan errors or unexpected destroy

Run `terraform fmt -check`, inspect backend/workspace and selected AWS identity/region, then inspect the full plan. Do not apply if it replaces stateful resources unexpectedly. Validate CIDR, AZ availability, engine versions and account quotas. Keep plan/state private; they can expose sensitive values.

## High latency or DB connection failures

Correlate request IDs with logs, RDS connection/CPU/storage metrics, cache status, and HPA/rollout events. Check application pool × replicas against DB capacity. Do not increase pool size blindly. If Redis is down, measure expected DB load while cache is bypassed.
