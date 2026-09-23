# Runbooks and failure lab

Use a disposable local Compose environment or a non-production cluster only. Capture baseline signals first. For every drill, state the hypothesis, change one variable, observe impact, recover, and record evidence. Do not deliberately break shared/prod AWS resources. The exercises below are safe procedures, not failures executed against your account.

## Wrong image / ImagePullBackOff

Set chart image tag to a deliberately nonexistent value in an isolated namespace. Sync. Inspect `kubectl describe pod` events and distinguish not-found from authorization/network errors. Recover by restoring a known immutable release tag in Git and syncing; verify ready replicas and ALB target health.

## Failed probe / CrashLoopBackOff

In a disposable local override, configure the readiness path to an invalid path (or use a temporary bad chart value in a sandbox). Observe ready endpoint count and deployment events. Liveness failures restart pods; readiness failures remove endpoints without restart. Restore probe path and verify rollout.

## Wrong Service selector

Change one selector label in a local/sandbox chart. Inspect `kubectl get endpoints` and the Service selector. Restore matching `app.kubernetes.io/name` and instance labels; confirm endpoints return.

## Database unavailable

Stop the local Postgres service (`docker compose stop postgres`). Confirm readiness becomes 503 and task writes fail safely; inspect logs. Restart Postgres, wait healthy, and verify readiness/data. Do not run destructive DB tests on real data.

## Redis unavailable

Stop local Redis. Confirm readiness stays 200 with `degraded`, and task CRUD still works through PostgreSQL. Restart Redis and check healthy.

## Failed deployment / migration

In sandbox, use an invalid image tag or intentionally invalid migration revision on a temporary branch. Observe CI/Argo or the PreSync Job gate. Revert the isolated change. Never sabotage a shared deployment. A DB migration rollback is a separate reviewed operation.

## Terraform validation failure

Copy the Terraform tree to a temporary directory outside the repo, introduce invalid HCL there, and run `terraform fmt`/`validate`; inspect line and provider diagnostics. Delete the scratch copy after. Do not corrupt the tracked configuration or apply a broken plan.

## GitHub Actions failure

On a throwaway branch, change a test assertion to fail, push, and inspect the test job summary/log. Restore the assertion and rerun. Do not print GitHub/AWS secret values in a workflow.

## Argo CD drift

In a sandbox, change a harmless replica count using `kubectl scale`. Observe OutOfSync/self-heal, then verify Argo returns the workload to Git desired state. Do not change IAM, networking, or data resources as a drift exercise.

## Database slowdown / connection exhaustion

Do not exhaust a shared managed database. Use a local throwaway DB and a bounded concurrency test. Capture connection count/latency, stop load, and verify recovery. Add pool limits only from measured evidence.
