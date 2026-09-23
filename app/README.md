# Devopshere API

A learning-lab task API built to exercise application delivery and operations. PostgreSQL is the source of truth. Redis is a disposable read cache: a cache outage degrades performance but does not lose task data.

## Layout

- src/devopshere_api/: API, configuration, database, cache, schemas, and routes.
- tests/: API contract and dependency failure tests; SQLite and a fake Redis keep unit tests local.
- migrations/: Alembic schema migrations.
- requirements.txt: pinned runtime dependencies.
- requirements-dev.txt: pinned test dependencies.
- docker-compose.yml: local PostgreSQL and Redis, bound to loopback only.
- .env.example: fake local-only values; copy to ignored .env before running local services.

## Start local dependencies

From this directory:

~~~powershell
Copy-Item .env.example .env
docker compose up -d
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
alembic upgrade head
pytest
uvicorn devopshere_api.main:app --app-dir src --reload
~~~

The app runs at localhost:8000. Open /docs for API documentation. Check /health/live and /health/ready. PostgreSQL must be healthy for readiness. Redis is optional for readiness because task reads fall back to PostgreSQL if Redis is unavailable.

To stop the local services while keeping database data, run docker compose down. To discard the local database volume as well, run docker compose down -v. The volume contains local test data.

## API

- POST /api/v1/tasks — create a task.
- GET /api/v1/tasks — list tasks with limit and offset.
- GET /api/v1/tasks/{id} — read one task.
- PATCH /api/v1/tasks/{id} — update title, description, or status.
- DELETE /api/v1/tasks/{id} — delete a task.
- GET /health/live — process liveness; no dependency calls.
- GET /health/ready — PostgreSQL required; Redis status is reported as ok, degraded, or disabled.

Valid statuses are open, in_progress, and done. Titles are trimmed, required, and limited to 140 characters. Descriptions are optional and limited to 2,000 characters.

## Local configuration and secrets

The tracked .env.example is a deliberately fake local template. The real local .env is ignored. Never place AWS credentials, real database credentials, private endpoints, customer data, or production URLs in tracked files. Provide production configuration through runtime secret injection after the AWS secret-store design is deployed. Local Compose defaults must never be reused in a deployed environment.
