#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "SERVICES"
docker compose --env-file .env ps
echo
echo "PUBLISHED HOST PORTS"
docker ps --format 'table {{.Names}}\t{{.Ports}}' | sed -n '1p;/0\.0\.0\.0\|127\.0\.0\.1\|:::/p'
