#!/usr/bin/env bash
set -euo pipefail
printf '%-24s %-24s %s\n' SERVICE CONTAINER_PORTS HOST_BINDINGS
printf '%-24s %-24s %s\n' '-----------------------' '-----------------------' '-----------------------'
docker ps --format '{{.Names}}|{{.Ports}}' | sort | while IFS='|' read -r name ports; do
  internal=$(printf '%s' "$ports" | tr ',' '\n' | sed -E 's/^[[:space:]]+//' | grep -E '^[0-9]+/(tcp|udp)$' | paste -sd, - || true)
  published=$(printf '%s' "$ports" | tr ',' '\n' | sed -E 's/^[[:space:]]+//' | grep '->' | paste -sd, - || true)
  printf '%-24s %-24s %s\n' "$name" "${internal:--}" "${published:--}"
done
