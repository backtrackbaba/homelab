# Media automation stack

Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, qBittorrent, Navidrome, and
Seerr. Independent Compose project (`saiprasad-media`) from the homelab
core stack and from `stacks/photos`.

## Storage

All paths derive from `DATA_ROOT` in `.env` (same root as the core stack):

```text
${DATA_ROOT}/appdata/media/{sonarr,radarr,prowlarr,bazarr,qbittorrent,navidrome}
${DATA_ROOT}/media/{movies,tv,music}
${DATA_ROOT}/downloads/{incomplete,complete}
```

qBittorrent, Sonarr, Radarr, and Bazarr all mount the **entire**
`${DATA_ROOT}:/data` as one bind mount, rather than separate mounts for
media and downloads. This matters: two separate `volumes:` entries each
become their own mount point inside the container, and hardlinks fail
with `Cross-device link` across them even though both point at
subdirectories of the same real filesystem on the Mac. A single shared
mount fixes this — verified via the hardlink test in
`docs/MEDIA-PHOTOS-STORAGE.md`, which also covers the tradeoff (these
containers can see `appdata/`/`immich/` too, not just their own paths).
Re-run that test after any storage change, including the eventual move
to external storage.

Navidrome mounts `${MEDIA_ROOT}/music` **read-only**; it has no need to
write tags or artwork in this phase.

## Ports

| Service | Port | Notes |
|---|---:|---|
| qBittorrent WebUI | 8090 | `QBITTORRENT_WEBUI_PORT` in `.env`; default 8080 conflicts with an existing container on this Mac |
| qBittorrent torrenting | 6881/tcp, 6881/udp | |
| Sonarr | 8989 | |
| Radarr | 7878 | |
| Prowlarr | 9696 | |
| Bazarr | 6767 | |
| Lidarr | 8686 | |
| Navidrome | 4533 | |
| Seerr | 5055 | |

All bound to `${BIND_ADDRESS}` (default `0.0.0.0`) — reachable on the LAN
and over Tailscale, never through a router port forward. No VPN is
configured for qBittorrent; do not route its traffic through one without a
separate explicit decision.

## Operating

```bash
make media-up
make media-down
make media-logs SERVICE=sonarr
make media-status
make media-update
```

## Navidrome status

Deployed and verified as of the Phase 2 pilot, ahead of the rest of this
stack. Admin account created through its web UI at `:4533` — unlike
Jellyfin, Navidrome's first-run admin creation is not a documented REST
endpoint (it's driven by the React SPA's internal calls), so this one
needs a human at the browser rather than API scripting. Credential stored
as `NAVIDROME_ADMIN_PASSWORD` in the repo root's `secrets.enc.env`.
Verified: library scan picks up new files automatically (file-watcher on
`/music`), and Subsonic-protocol streaming (`/rest/stream.view`) works,
which is what Android clients like Symfonium use.

## Lidarr

Music's equivalent of Sonarr/Radarr — monitors artists/albums and grabs
via indexers, same pattern as the rest of the Arr family. Wired up the
same way: forms auth (`ARR_STACK_ADMIN_PASSWORD`, username `sai`),
qBittorrent as its download client (category `lidarr`), root folder at
`/data/media/music`, registered as an application in Prowlarr. Like
Sonarr/Radarr, it currently has no indexer and cannot search or grab
anything — deployed ahead of that so the wiring is ready. There is no
polished "Seerr for music"; until there's a real source to search
against, dropping a legally-sourced audio file into
`${MEDIA_ROOT}/music` and letting Navidrome's file-watcher pick it up
(already verified working) remains the simplest real workflow for a
single-listener setup.

## Seerr

Request/discovery UI (`ghcr.io/seerr-team/seerr`, the current
Jellyseerr/Overseerr successor) — search a title, request it, it flows to
Sonarr/Radarr, notified when it lands in Jellyfin. This is the intended
"request from my phone" front-end; nothing else in this stack should be
used as the request path once this is set up on a device.

No separate Seerr credential exists: its admin account authenticates
directly against the existing Jellyfin account (`sai`), using
`/api/v1/auth/jellyfin` with `serverType: 2` (Jellyfin). Sonarr and Radarr
are both registered as servers (`activeProfileId: 4` / HD-1080p,
`isDefault: true`). Availability status syncs from Sonarr/Radarr on
its own schedule (`sonarr-scan`/`radarr-scan` jobs); verified correct
after a manual run — see the Pioneer One test below.

## Rollout status (Phase 3 pilot) — complete, verified end-to-end

1. ✅ Stack brought up with no indexers/downloads configured.
2. ✅ qBittorrent: permanent admin credential set (`QBITTORRENT_ADMIN_PASSWORD`
   in `secrets.enc.env`). Hit a real gotcha here — see below.
3. ✅ Sonarr/Radarr/Prowlarr: forms authentication configured
   (`ARR_STACK_ADMIN_PASSWORD`, username `sai`). Bazarr: form auth
   configured the same way via its own settings API.
4. ✅ Prowlarr connected to Sonarr and Radarr as Applications (`addOnly`
   sync). Sonarr and Radarr both have qBittorrent wired as their download
   client, verified healthy via each app's `/health` endpoint (no
   connectivity errors — only the expected "no indexers configured"
   warnings). Bazarr connected to both and reports their live versions.
   Seerr added and connected to Jellyfin + Sonarr + Radarr.
5. **Deliberately, permanently out of scope**: no indexer has been added
   anywhere, and none will be added for content without a lawful source.
   Adding one requires the operator to name a specific, lawful source.
6. ✅ **Full pipeline tested end-to-end** with *Pioneer One* (2010) — a
   series its creators released under CC BY-SA specifically via
   BitTorrent, officially seeded by archive.org itself
   (`archive.org/details/pioneer-one-ep.-1-earthfall-pilot`, torrent
   auto-generated by archive.org, not a third-party tracker):
   - Added to Sonarr as monitored (`searchForMissingEpisodes: false`,
     since no indexer exists to search with).
   - Root folders (`/data/media/tv`, `/data/media/movies`) registered in
     both Sonarr and Radarr — neither had one configured before this.
   - Episode 1's official archive.org torrent added directly to
     qBittorrent (category `tv-sonarr`) — downloaded in under 2 minutes.
   - Sonarr's manual import (`POST /api/v3/command` `ManualImport`)
     picked it up, matched it to the episode, and **hardlinked** it into
     `/data/media/tv/Pioneer One/` — confirmed via `copyUsingHardlinks:
     true` and the source file being cleaned up post-import (expected
     hardlink behavior, not data loss: the content lives on via the
     link in the media folder).
   - Appeared correctly in Jellyfin's new TV Shows library
     (`/Users/sai-mini/homelab/data/media/tv`) as a Series/Episode.
   - Seerr's `sonarr-scan` job picked it up and correctly reports
     `mediaInfo.status: 4` (Partially Available) — accurate, since only
     1 of 6 episodes was imported.
   - A stray qBittorrent gotcha along the way: its default save path
     was stale (`/downloads`, left over from before the `DATA_ROOT`
     single-mount fix), which put the very first torrent add into an
     `error` state with 0% progress. Fixed via
     `app/setPreferences` → `save_path`/`temp_path` pointed at
     `/data/downloads/{complete,incomplete}`.
7. ✅ `make storage-status` reflects real usage and the 120GB free-space
   floor alert is wired (verified against actual disk state).
   qBittorrent queueing capped at 3 active downloads / 5 active torrents
   as a coarse growth guardrail (qBittorrent has no native "pause below
   free space X" setting to hook into directly).

### qBittorrent gotcha: Host header validation

Accessing qBittorrent's WebUI through Docker's published port (i.e. from
the Mac host, not from inside the container) returned a bare `401
Unauthorized` for *every* request, including the login page itself —
before any credentials were even involved. This is qBittorrent 5.x's Host
header validation rejecting requests that arrive through Colima's
port-forwarding path, which don't look "local" to it. `ServerDomains=*`
in its config did **not** fix this (the wildcard doesn't reliably work in
this version); the working fix was setting
`WebUI\HostHeaderValidation=false` directly in
`${APPDATA_ROOT}/qbittorrent/qBittorrent/qBittorrent.conf` while the
container was stopped. This persists on the host bind mount, so it
survives container recreation — but if that config directory is ever
reset, this needs reapplying before the WebUI is reachable from outside
the container at all.

### Prowlarr uses a different API version

Sonarr and Radarr's REST API is at `/api/v3/...`; Prowlarr — despite
sharing the same Servarr codebase — uses `/api/v1/...`. Easy to trip over
when scripting against all three uniformly.

No FlareSolverr, no piracy-oriented indexers, no automated bulk
acquisition — this stack is for lawfully obtained or owned media only.
