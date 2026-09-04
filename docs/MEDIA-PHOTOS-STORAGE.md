# Media and photos storage

## Why this lives under $HOME, not /Users/Shared

The container runtime on this Mac is Colima, running Docker inside a Linux
VM via macOS's Virtualization.framework. Colima only shares `$HOME` into
that VM by default — `/Users/Shared` is not mounted. A bind mount pointing
outside the shared tree does not error; Docker silently creates an empty,
root-owned directory *inside the VM's own disk* at that path instead,
completely disconnected from the real file on macOS. This was hit and
fixed during the core stack's first deployment (see git history). Any
future storage path — including the eventual move to external storage —
must either live under a path Colima already shares, or be added to
Colima's `mounts:` config first (`~/.colima/default/colima.yaml`), which
requires restarting the VM and briefly restarts every other container on
this machine, not just this repo's.

## Layout

Everything shares the core stack's `DATA_ROOT`:

```text
/Users/sai-mini/homelab/data/
├── appdata/
│   ├── media/
│   │   ├── sonarr/
│   │   ├── radarr/
│   │   ├── prowlarr/
│   │   ├── bazarr/
│   │   ├── qbittorrent/
│   │   └── navidrome/
│   └── immich/
│       └── database/
├── downloads/
├── media/
│   ├── movies/
│   ├── tv/
│   └── music/
└── immich/
    └── upload/
```

One env var per stack (`DATA_ROOT` in each `stacks/*/.env`) controls all of
it. Moving to external storage later means changing that one value —
**and** adding the new mount point to Colima, per above.

## Hardlink verification

qBittorrent and the Arr apps expect to hardlink a finished download into
the media library instead of copying it. This does **not** just need
`DOWNLOAD_ROOT` and `MEDIA_ROOT` to be on the same host filesystem — it
needs them to be part of the *same bind mount* inside the container.
Two separate `volumes:` entries (`${MEDIA_ROOT}:/data/media` and
`${DOWNLOAD_ROOT}:/data/downloads`) each become their own mount point
inside the container, which looks like a different device to `ln(1)`
even though both point at subdirectories of the same real filesystem on
the Mac — this was hit directly during the Phase 3 pilot (`Cross-device
link`, despite `MEDIA_ROOT` and `DOWNLOAD_ROOT` both living under
`DATA_ROOT`).

The fix — already applied in `stacks/media/compose.yaml` — is to mount
the shared parent once: `${DATA_ROOT}:/data`, so `/data/media` and
`/data/downloads` are both inside a single bind mount. This is also the
standard pattern in the wider Servarr/TRaSH-guides community, for exactly
this reason. It does mean qBittorrent, Sonarr, Radarr, and Bazarr can see
`appdata/` and `immich/` inside their container too, not just their
own working paths — an acceptable trade-off for a single-operator
homelab with no untrusted users, but worth knowing.

Verify hardlinks are actually working after any mount change (including
the eventual move to external storage):

```bash
docker compose -f stacks/media/compose.yaml exec sonarr sh -c '
  set -e
  echo test > /data/downloads/hardlink-test.txt
  ln /data/downloads/hardlink-test.txt /data/media/hardlink-test.txt
  ls -li /data/downloads/hardlink-test.txt /data/media/hardlink-test.txt
  # inode numbers must match and link count must be 2 for a real hardlink
  rm /data/downloads/hardlink-test.txt /data/media/hardlink-test.txt
'
```

If the inode numbers ever differ again, fall back to a safe
copy-then-verify-then-delete workflow (Sonarr/Radarr Settings → Media
Management → disable "Use Hardlinks instead of Copy") and document the
extra disk churn this causes.

## Internal SSD guardrails

The internal SSD is 512 GB, non-upgradeable. Policies for this phase:

- Keep at least 100–120 GB free at all times. `make storage-status` alerts
  below 120 GB.
- Keep the trial media library roughly within 100–150 GB.
- Keep active/incomplete downloads within roughly 30–50 GB — set a
  qBittorrent queue/seeding limit accordingly.
- Start Immich with one small representative album, not a full phone
  archive.
- `make storage-status` reports host free space, Colima VM disk
  allocation, Docker's own disk usage, and a size breakdown of
  `DATA_ROOT`.

Treat any of the following as a trigger to plan external storage rather
than deleting data to stay afloat:

- Free space repeatedly falls below 120 GB.
- Media approaches 150–200 GB.
- Immich is ready to become the primary photo archive.
- Downloads become sustained rather than experimental.
- Data is being deleted merely to keep the system operational.

## Data classification (for backup design)

**Irreplaceable** — needs real, versioned, off-machine backup eventually:
Immich's uploaded originals and its database, hand-curated media, and
application configuration that would be painful to reconstruct.

**Reconstructable** — a same-disk dump/cache is fine, no urgency:
container images, lawfully re-downloadable media, thumbnails/transcode
caches, in-progress downloads, logs.

During this internal-SSD-only phase, Immich must not be the only copy of
personal photos — keep the existing iCloud/Google Photos/phone copy
intact. See `stacks/photos/README.md` for the Immich-specific backup and
restore procedure.
