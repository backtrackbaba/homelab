# Immich photo/video server

Adapted minimally from the official Immich release Compose file (see the
header comment in `compose.yaml` for the exact diffs from upstream).
Independent Compose project (`immich`) with its own dedicated Postgres and
Redis — never the homelab core stack's shared Postgres/Redis, and never
coupled to the media automation stack's availability.

## Storage

```text
${DATA_ROOT}/immich/upload              # originals, host-visible bind mount
${DATA_ROOT}/appdata/immich/database    # Immich's own Postgres data
```

The upload location is a bind mount, not a Docker named volume, so
originals stay visible from Finder/backup tooling and migratable by
changing one path.

## Secrets

`DB_PASSWORD` is **not** set for real in this directory's `.env` — the
committed `.env.example` only has a placeholder so `docker compose config`
can validate offline. The real value lives in the repo root's
`secrets.enc.env` as `IMMICH_DB_PASSWORD`, and `make photos-up` injects it
as `DB_PASSWORD` at invocation time (shell environment overrides the local
`.env` file). Never put the real password in `stacks/photos/.env`.

## Resource limits

This Mac also runs LM Studio and native Jellyfin. There is no Apple
GPU/NPU acceleration for containerized Immich on macOS in this phase —
machine learning, facial recognition, smart search, and video transcoding
all run on CPU. `immich-machine-learning` is capped at `mem_limit: 4g`,
`cpus: 2`, and `MACHINE_LEARNING_WORKERS=1` in `.env`. Revisit these only
after the Phase 5 observation period, with measured data.

## Ports

| Service | Port |
|---|---:|
| immich-server | 2283 |

Postgres and Redis are not published to the host. Bound to `${BIND_ADDRESS}`
(default `0.0.0.0`) — LAN/Tailscale only, never a router port forward.

## Operating

```bash
make photos-up
make photos-down
make photos-logs SERVICE=immich-server
make photos-status
make photos-update
```

## Backup and restore

- `make photos-update` takes a database backup before touching anything —
  see the target in the root `Makefile` for the exact `pg_dumpall` command
  and where the dump lands.
- A database backup alone is **not** sufficient: it recovers metadata, not
  the uploaded originals. A real restore needs both the database dump and
  `${DATA_ROOT}/immich/upload`.
- Do not disable or delete any existing cloud/phone photo backup during
  this pilot — Immich is not the sole copy of personal photos yet.
- Read Immich's release notes before bumping `IMMICH_VERSION`:
  https://docs.immich.app/administration/backup-and-restore

## Rollout order

1. Bring the stack up empty, confirm the web UI loads and accepts the
   first-run admin account creation.
2. Upload one small, representative test album — not the full phone
   archive.
3. Verify: upload, timeline, thumbnail generation, search, face
   detection, and mobile app login.
4. Take a database backup, then deliberately exercise a restore into a
   throwaway location to prove the backup is real before trusting it.
5. Only after that, consider growing the pilot — see Phase 5 in the
   project's media/photos planning context for what to measure first.
