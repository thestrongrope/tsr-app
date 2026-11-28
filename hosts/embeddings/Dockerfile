FROM python:3.12-slim

# uv for dependency management (project standard: no bare pip).
COPY --from=ghcr.io/astral-sh/uv:0.11.16 /uv /usr/local/bin/uv

ENV EMBEDDING_MODEL=BAAI/bge-small-en-v1.5 \
    FASTEMBED_CACHE_PATH=/opt/fastembed-cache \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1

WORKDIR /app

# The exact versions are in uv.lock; --frozen refuses to change it, so a build cannot drift to another fastembed (the model and pooling must not change).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project --no-cache

# Bake the ONNX model into the image, using the same cache path as runtime.
COPY warmup.py ./
RUN python warmup.py

COPY app.py ./

EXPOSE 8000

# python-based check: this base image has no curl, and BusyBox wget's --spider
# is not available here either.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4).status==200 else 1)"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
