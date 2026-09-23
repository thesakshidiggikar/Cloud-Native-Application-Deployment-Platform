# Devopshere API

This is the first application task: a small FastAPI service with separate liveness and readiness endpoints, environment-based settings, JSON logs, and tests. Readiness currently covers only the process; PostgreSQL and Redis checks will be added with dependency integration.

## Layout

- src/devopshere_api/: importable application package.
- tests/: automated API contract checks.
- requirements.txt: pinned runtime dependencies.
- requirements-dev.txt: pinned local test dependencies.
- pytest.ini: test discovery and source import configuration.
- .env.example: fake, non-secret local configuration values.

## Local setup

Use Python 3.12 or later. Create and activate a virtual environment from this directory, then run:

~~~powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
Copy-Item .env.example .env
pytest
uvicorn devopshere_api.main:app --app-dir src --reload
~~~

The API documentation is available at /docs while the server is running. Check /health/live and /health/ready. Do not put credentials or real account values in .env.example or Git; keep local .env untracked.
