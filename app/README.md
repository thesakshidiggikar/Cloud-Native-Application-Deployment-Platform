# Devopshere API

A learning-lab task API built to exercise application delivery and operations. PostgreSQL is the source of truth. Redis is a disposable read cache: a cache outage degrades performance but does not lose task data.

## Layout

- src/devopshere_api/: API, configuration, database, cache, schemas, and routes.
- tests/: API contract and dependency failure tests; SQLite and a fake Redis keep unit tests local.
- migrations/: Alembic schema migrations.
- requirements.txt: pinned runtime dependencies.
- requirements-dev.txt: pinned test dependencies.
- docker-compose.yml: local API, PostgreSQL, and Redis services; ports bind to loopback.
- .env.example: fake local-only values; copy it to ignored .env before starting Compose.

## Run the full container stack

From this directory:

~~~powershell
Copy-Item .env.example .env
docker compose up --build -d
docker compose ps
Invoke-RestMethod http://127.0.0.1:8000/health/live
Invoke-RestMethod http://127.0.0.1:8000/health/ready
~~~

Open http://127.0.0.1:8000/docs for API documentation. The Compose migration job waits for PostgreSQL and creates the schema before the API starts. PostgreSQL must be healthy for readiness. Redis is optional for readiness because task reads fall back to PostgreSQL when Redis is unavailable.

To inspect service output, run docker compose logs --follow api. To stop services while preserving the local database, run docker compose down. To delete the disposable local database volume too, run docker compose down -v.

## Run tests and the API directly from Python

This mode is useful for a reload-on-save loop. Do not start the Compose api service at the same time because both modes use port 8000.

~~~powershell
docker compose up -d postgres redis
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
alembic upgrade head
pytest
uvicorn devopshere_api.main:app --app-dir src --reload
~~~

The unit tests use temporary SQLite and a fake Redis; they do not require Docker or AWS. The Alembic command uses the local APP_DATABASE_URL in .env and applies the production migration to the local PostgreSQL container.

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

The tracked .env.example contains deliberately fake local values. The real .env is ignored. Never place AWS credentials, real database credentials, private endpoints, customer data, or production URLs in tracked files. Production configuration will come from runtime secret injection. Local Compose values must never be reused in a deployed environment.
