# Stage 1: dependency resolver
FROM python:3.13-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
COPY fli/ ./fli/

RUN uv sync --frozen --no-dev --no-cache


# Stage 2: minimal runtime
FROM python:3.13-slim AS runtime

WORKDIR /app

# Copy only the installed venv and source from the builder
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/fli /app/fli

ENV PATH="/app/.venv/bin:$PATH"
ENV VIRTUAL_ENV="/app/.venv"
ENV PYTHONUNBUFFERED=1
ENV HOST="0.0.0.0"
ENV PORT="8000"

EXPOSE 8000

# Run as non-root
RUN useradd --no-create-home --shell /bin/false appuser
USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('localhost', 8000)); s.close()" || exit 1

CMD ["fli-mcp-http"]
