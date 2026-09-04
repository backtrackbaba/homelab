#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/decrypt-secrets.sh
set -a
source .runtime/secrets.env
set +a
docker compose --env-file .env up -d
./scripts/status.sh
