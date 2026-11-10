#!/bin/sh
# Runs inside the dev database container on its first start only (docker-compose.dev.yml).
# Applies db/migrations in name order, then the synthetic seed. Production never uses this:
# there, tsr-migrate applies migrations (docs/dev/migrations.md in tsr-account).
set -e

for file in /tsr-db/migrations/*.sql; do
  echo "dev-init: applying $(basename "$file")"
  docker_process_sql < "$file"
done

echo "dev-init: loading synthetic seed"
docker_process_sql < /tsr-db/synthetic/seed.sql
