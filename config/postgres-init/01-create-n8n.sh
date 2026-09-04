#!/bin/sh
set -eu

if [ -z "${N8N_DB_USER:-}" ] || [ -z "${N8N_DB_NAME:-}" ] || [ -z "${DB_POSTGRESDB_PASSWORD:-}" ]; then
  echo "n8n database bootstrap variables are missing" >&2
  exit 1
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER ${N8N_DB_USER} WITH PASSWORD '${DB_POSTGRESDB_PASSWORD}';
  CREATE DATABASE ${N8N_DB_NAME} OWNER ${N8N_DB_USER};
EOSQL
