#!/usr/bin/env bash
# Read-only disk usage report. Never deletes anything.
set -euo pipefail
cd "$(dirname "$0")/.."

DATA_ROOT=$(sed -n 's/^DATA_ROOT=//p' .env | tail -n 1)
FLOOR_GB=120

echo "HOST FREE SPACE"
df -H / | awk 'NR==1{print} NR==2{print}'
avail_g=$(df -g / | awk 'NR==2{print $4}')
if [ "${avail_g:-0}" -lt "$FLOOR_GB" ]; then
  echo "ALERT: free space (${avail_g}G) is below the ${FLOOR_GB}G floor"
fi
echo

echo "COLIMA VM DISK"
colima list 2>/dev/null | awk 'NR==1{print} NR==2{print}' || echo "colima not available"
echo

echo "DOCKER DISK USAGE"
docker system df
echo

if [ -d "$DATA_ROOT" ]; then
  echo "DATA_ROOT BREAKDOWN ($DATA_ROOT)"
  du -sh "$DATA_ROOT"/* 2>/dev/null | sort -rh
  echo

  if [ -d "$DATA_ROOT/media" ]; then
    echo "MEDIA:      $(du -sh "$DATA_ROOT/media" 2>/dev/null | cut -f1)"
  fi
  if [ -d "$DATA_ROOT/downloads" ]; then
    echo "DOWNLOADS:  $(du -sh "$DATA_ROOT/downloads" 2>/dev/null | cut -f1)"
  fi
  if [ -d "$DATA_ROOT/immich" ]; then
    echo "IMMICH:     $(du -sh "$DATA_ROOT/immich" 2>/dev/null | cut -f1)"
  fi
  if [ -d "$DATA_ROOT/appdata" ]; then
    echo "APPDATA:    $(du -sh "$DATA_ROOT/appdata" 2>/dev/null | cut -f1)"
  fi
else
  echo "DATA_ROOT ($DATA_ROOT) does not exist yet; run make bootstrap"
fi
