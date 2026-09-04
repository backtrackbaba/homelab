#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || { echo "Docker is required" >&2; exit 1; }
command -v sops >/dev/null || { echo "Install sops: brew install sops" >&2; exit 1; }
command -v age >/dev/null || { echo "Install age: brew install age" >&2; exit 1; }

[ -f .env ] || cp .env.example .env
mkdir -p .runtime
chmod 700 .runtime

DATA_ROOT=$(grep '^DATA_ROOT=' .env | cut -d= -f2-)
STACKS_ROOT=$(grep '^STACKS_ROOT=' .env | cut -d= -f2-)
mkdir -p "$DATA_ROOT" "$STACKS_ROOT"
for dir in npm/data npm/letsencrypt postgres redis n8n ntfy/cache ntfy/lib speedtest uptime-kuma dockge; do
  mkdir -p "$DATA_ROOT/$dir"
done

if [ ! -f secrets.enc.env ]; then
  echo "Create secrets.enc.env first; see docs/SECRETS.md" >&2
  exit 1
fi

./scripts/decrypt-secrets.sh
mkdir -p "$STACKS_ROOT/core"
cp compose.yaml "$STACKS_ROOT/core/compose.yaml"
echo "Bootstrap complete. Review .env, then run: ./scripts/up.sh"
