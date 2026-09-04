#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .runtime
chmod 700 .runtime
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" sops --decrypt secrets.enc.env > .runtime/secrets.env
chmod 600 .runtime/secrets.env

get_secret() {
  local key="$1"
  sed -n "s/^${key}=//p" .runtime/secrets.env | tail -n 1
}

get_secret POSTGRES_ADMIN_PASSWORD > .runtime/postgres_admin_password
get_secret REDIS_PASSWORD > .runtime/redis_password
chmod 600 .runtime/postgres_admin_password .runtime/redis_password
