# Media automation stack

Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, and Navidrome. Independent
Compose project (`saiprasad-media`) from the homelab core stack and from
`stacks/photos`.

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
| Navidrome | 4533 | |

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

## Rollout status (Phase 3 pilot)

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
5. ⬜ **Not done, by design**: no indexer has been added anywhere. Adding
   one requires the operator to name a specific, lawful source — nothing
   is configured until that happens.
6. ⬜ Once an indexer is approved: test with a single, small,
   manually-selected item before enabling any broader automation.
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
