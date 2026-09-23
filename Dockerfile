# syntax=docker/dockerfile:1.7
FROM python:3.12.13-slim-bookworm@sha256:6e13e65c55e33adf203d77ee371cf8bf5d81bd4902ef07565721f46bf44917af AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /build
COPY app/requirements.txt /build/requirements.txt
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r /build/requirements.txt

FROM python:3.12.13-slim-bookworm@sha256:4766d8b510c428e595d74b9cc5bbb2fae8e26316fffb4adc89908d79aacd58a AS runtime

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_LOG_LEVEL=INFO

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app --create-home app
WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app/src/ /app/src/
COPY --chown=app:app app/migrations/ /app/migrations/
COPY --chown=app:app app/alembic.ini /app/alembic.ini

USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/health/live', timeout=2)"]
CMD ["uvicorn", "devopshere_api.main:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]

