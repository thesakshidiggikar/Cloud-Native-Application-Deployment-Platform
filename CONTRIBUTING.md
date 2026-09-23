# Git workflow

- `main`: reviewed release state.
- `develop`: integration branch.
- `feature/<scope>`: change branch, for example `feature/application`, `feature/docker`, `feature/terraform-network`, `feature/eks`, `feature/helm`, `feature/argocd`.
- Change -> test -> commit -> push -> PR -> review -> merge. Do not commit directly to `main`.

Commit format: `type(scope): summary`; types include `feat`, `fix`, `docs`, `test`, `build`, `ci`, `refactor`, `security`. Example: `ci(publish): use OIDC for ECR uploads`.

Before PR: run unit tests, `terraform fmt -check -recursive`, `terraform validate`, `helm lint`, `helm template`, secret scan and review `git diff --check`. CI repeats automated checks. Configure branch protections and required checks in GitHub repository settings; workflow files alone do not enforce branch policy.
