# Build stage
FROM python:3.13-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
COPY fli/ ./fli/

RUN uv sync --no-dev --frozen

# Runtime stage
FROM python:3.13-slim

RUN groupadd --gid 1000 fli && \
    useradd --uid 1000 --gid fli --shell /bin/bash --create-home fli

WORKDIR /app

COPY --from=builder --chown=fli:fli /app /app

ENV PATH="/app/.venv/bin:$PATH"
ENV VIRTUAL_ENV="/app/.venv"
ENV HOST=0.0.0.0
ENV PORT=8000

USER fli

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('localhost', 8000)); s.close()" || exit 1

CMD ["fli-mcp-http"]
