"""Download + cache the ONNX model at image build time.

Run during `docker build` with the same FASTEMBED_CACHE_PATH used at runtime,
so the container starts fully offline and the first request pays no download.
"""

import os

from fastembed import TextEmbedding

model_name = os.environ["EMBEDDING_MODEL"]
cache_dir = os.environ["FASTEMBED_CACHE_PATH"]

model = TextEmbedding(model_name=model_name, cache_dir=cache_dir)

# Force a real forward pass so any lazy initialisation happens now, and assert
# the dimension the Elasticsearch mapping expects.
vector = next(iter(model.embed(["warmup"]))).tolist()
assert len(vector) == 384, f"expected 384 dims, got {len(vector)}"

print(f"cached {model_name} ({len(vector)} dims) in {cache_dir}")
