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

Admin login is separate: `IMMICH_ADMIN_PASSWORD` in `secrets.enc.env`,
account email `sai@homelab.local`, created via `/api/auth/admin-sign-up`
on first deploy.

**A real bug was hit and fixed here**: `immich-server` declares
`env_file: .env` *and* needs the real `DB_PASSWORD` injected via shell at
invocation time. Those two don't compose the way they look like they
should — `env_file` loads the literal `DB_PASSWORD=changeme` placeholder
from the `.env` file as a container environment variable directly,
independent of shell-level `${DB_PASSWORD}` substitution elsewhere in the
compose file. The `database` service picked up the real secret (via
`environment: POSTGRES_PASSWORD: ${DB_PASSWORD}`, which *is* substituted),
but `immich-server` silently got the placeholder and failed to
authenticate (`password authentication failed for user "immich"`,
crash-looping). Fixed by adding an explicit
`environment: DB_PASSWORD: ${DB_PASSWORD}` on `immich-server`, which wins
over the `env_file` value for the same key. Worth remembering for any
other service that mixes `env_file` with secrets injected via shell env.

## Resource limits

This Mac also runs LM Studio and native Jellyfin. There is no Apple
GPU/NPU acceleration for containerized Immich on macOS in this phase —
machine learning, facial recognition, smart search, and video transcoding
all run on CPU. `immich-machine-learning` is capped at `mem_limit: 4g`,
`cpus: 2`, and `MACHINE_LEARNING_WORKERS=1` in `.env` — confirmed applied
(`docker stats` shows the 4GiB limit in effect, not the host's full 24GB).

Also lowered every job's `concurrency` in Immich's own admin settings
(System Settings → Jobs) from its aggressive multi-user defaults (mostly
5) down to 1–2 across the board, `smartSearch`/`faceDetection`/
`videoConversion` (the heaviest CPU jobs) at 1. Idle baseline measured
before any real photos were uploaded:

| Container | CPU | Memory |
|---|---:|---:|
| immich_server | 0.3% | 736 MiB |
| immich_machine_learning | 0.2% | 269 MiB |
| immich_postgres | 0.7% | 421 MiB |
| immich_redis | 0.2% | 15 MiB |

Revisit concurrency/limits only after the Phase 5 observation period,
with real usage data once actual photos are imported.

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

## Backup and restore — done, tested, both mechanisms verified

Two independent backup paths exist, deliberately:

1. **Immich's own built-in scheduled backup** (already enabled by
   default: daily at 02:00, keeps the last 14) — dumps just the `immich`
   database with `pg_dump` to
   `${DATA_ROOT}/immich/upload/backups/immich-db-backup-*.sql.gz`. This
   is the one that runs continuously without anyone doing anything.
2. **`make photos-backup`** (and `make photos-update`, which runs it
   automatically first) — a separate `pg_dumpall` covering the whole
   Postgres cluster, written to `backups/immich/` in the repo root
   (gitignored). This is the pre-update safety net, run right before a
   risky `IMMICH_VERSION` bump.

**Both were actually tested, not just configured**: triggered Immich's
backup job via `PUT /api/jobs/backupDatabase`, confirmed the `.sql.gz`
landed on the real host filesystem (not just inside the container), then
restored it into a completely throwaway `immich_postgres`-image
container (`docker run`, no compose, no shared volumes) and queried the
restored `user` table — the real admin account (`sai@homelab.local`,
`isAdmin: true`) came back correctly. That container was then deleted.
This is what "the backup is real" actually means, versus a file that
merely exists.

A database backup alone is **not** sufficient for a full disaster
recovery: it covers metadata, not the uploaded originals. A real restore
needs both a database dump and `${DATA_ROOT}/immich/upload`. Do not
disable or delete any existing cloud/phone photo backup during this
pilot — Immich is not the sole copy of personal photos yet.

Read Immich's release notes before bumping `IMMICH_VERSION`:
https://docs.immich.app/administration/backup-and-restore

## Rollout status (Phase 4 pilot)

1. ✅ Stack deployed, all four containers healthy (`immich-server`,
   `immich-machine-learning`, dedicated `database`, dedicated `redis`).
   Hit and fixed a real `DB_PASSWORD` bug along the way — see Secrets
   above.
2. ✅ Admin account created via API (no browser needed, unlike Navidrome).
3. ✅ Job concurrency turned down from Immich's aggressive defaults;
   `mem_limit`/`cpus` confirmed actually enforced via `docker stats`.
4. ✅ Backup **and restore** both verified with a genuine throwaway
   restore, not just "the file exists."
5. ⬜ **Needs the operator, not the agent**: upload one small,
   representative test album from a phone/browser — this is personal
   photo content, not something to fabricate or substitute. Once
   uploaded, verify timeline, thumbnail generation, face detection, and
   search against real data, and re-measure resource usage under actual
   load (the table above is idle-only).
6. ⬜ Only after that, consider growing the pilot — see Phase 5 for what
   to measure first (media/photo growth rate, peak concurrent load,
   backup duration at real data size).
