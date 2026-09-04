#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

failed=0
check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'OK   command: %s\n' "$1"
  else
    printf 'MISS command: %s\n' "$1"
    failed=1
  fi
}
check_file() {
  if [ -f "$1" ]; then
    printf 'OK   file: %s\n' "$1"
  else
    printf 'MISS file: %s\n' "$1"
    failed=1
  fi
}

check_command docker
check_command sops
check_command age
check_file .env.example
check_file .env
check_file compose.yaml
check_file secrets.enc.env
check_file "$HOME/.config/sops/age/keys.txt"

if docker info >/dev/null 2>&1; then
  echo 'OK   Docker daemon is running'
else
  echo 'MISS Docker daemon is not running'
  failed=1
fi

if [ -f .env ]; then
  DATA_ROOT=$(sed -n 's/^DATA_ROOT=//p' .env | tail -n 1)
  STACKS_ROOT=$(sed -n 's/^STACKS_ROOT=//p' .env | tail -n 1)
  printf 'INFO repository: %s\n' "$PWD"
  printf 'INFO data root:  %s\n' "$DATA_ROOT"
  printf 'INFO stacks root:%s\n' "$STACKS_ROOT"
fi

exit "$failed"
