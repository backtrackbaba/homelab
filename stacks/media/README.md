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

qBittorrent and the Arr apps all mount `MEDIA_ROOT` and `DOWNLOAD_ROOT` at
the same container-internal paths (`/data/media`, `/data/downloads`), so no
remote path mapping is needed inside Sonarr/Radarr, and hardlinks between
downloads and the library are possible **only if** `DOWNLOAD_ROOT` and
`MEDIA_ROOT` are on the same host filesystem (true today; verify again
after moving to external storage — see the hardlink test in
`docs/`).

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

## Rollout order

1. Bring the stack up with no indexers/downloads configured yet.
2. Add qBittorrent credentials, confirm the WebUI is reachable.
3. Connect Prowlarr to qBittorrent and to Sonarr/Radarr.
4. Add exactly one lawfully-sourced indexer, approved by the operator.
5. Test with a single, small, manually-selected item before enabling
   any broader automation.
6. Confirm the download cap and `make storage-status` alerting work
   before leaving automation running unattended.

No FlareSolverr, no piracy-oriented indexers, no automated bulk
acquisition — this stack is for lawfully obtained or owned media only.
