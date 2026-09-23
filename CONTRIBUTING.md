# Contributing and Git Workflow

This public repository uses pull requests so each change is reviewable and each learning task leaves a clear record.

## Branches

- main: stable, reviewed project baseline.
- develop: integration branch for accepted work.
- feature/<short-scope>: one task or feature at a time, created from develop.
- fix/<short-scope>: a focused defect correction, created from develop.
- hotfix/<short-scope>: urgent correction to main, followed by synchronization into develop.

Examples:

- feature/application
- feature/docker
- feature/terraform-network
- feature/eks
- feature/helm
- feature/argocd

Do not develop directly on main or develop. Keep each branch focused and avoid combining unrelated phase work.

## Change sequence

1. Start from an up-to-date develop branch.
2. Create a feature branch for one small task.
3. Implement only that task.
4. Run the checks listed by the task and record the results.
5. Review the diff locally. Confirm no secrets, private data, local state, or generated files are staged.
6. Commit using a clear message.
7. Push the branch and open a pull request targeting develop.
8. Explain purpose, implementation, verification, and known limitations in the pull request.
9. Review all checks and comments; fix or discuss findings.
10. Merge only after review and required checks pass. Delete the remote feature branch after merge when it is no longer needed.
11. Promote reviewed develop to main through a release pull request.

## Commit messages

Use a short imperative summary with a conventional type:

- feat: add task creation endpoint
- fix: handle database timeout
- docs: explain local environment setup
- test: cover readiness behavior
- build: pin application dependencies
- ci: validate pull requests
- chore: add editor ignores
- refactor: isolate database access

Keep the subject specific and concise. Do not claim tests or deployment succeeded unless they were actually run.

## Public repository safety

- Treat every committed file and all Git history as public.
- Never commit passwords, access keys, tokens, private keys, real customer data, personal data, Terraform state, or production configuration.
- Use ignored local environment files for local-only values and provide fake, clearly named examples for required variables.
- Use GitHub environment secrets or a cloud secret manager at runtime. Prefer short-lived federation over long-lived keys.
- If a credential reaches Git, revoke/rotate it immediately. Removing it in a later commit does not erase the earlier public history.
- Do not rely on .gitignore as a secret detector; inspect staged changes before every commit.

## Pull request checklist

- [ ] The change is limited to one task.
- [ ] The branch is based on develop and the PR targets develop.
- [ ] Formatting, tests, and other checks relevant to the task have been run.
- [ ] The PR describes the change and its verification accurately.
- [ ] No credentials, personal data, local state, or generated files are included.
- [ ] The author has reviewed the complete diff.

## Bootstrap note

The initial requirements and architecture documents were drafted before develop existed and are in review as bootstrap pull requests. Review and land those in order, then fast-forward or merge the resulting main state into develop before starting the application feature branch.