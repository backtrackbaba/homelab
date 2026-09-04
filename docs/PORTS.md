# Port policy

Only the reverse proxy publishes application traffic to the Mac:

| Host binding | Owner | Purpose |
|---|---|---|
| `0.0.0.0:80` | Nginx Proxy Manager | HTTP / redirects |
| `0.0.0.0:443` | Nginx Proxy Manager | HTTPS gateway |
| `127.0.0.1:81` | Nginx Proxy Manager | Initial/local administration |
| `0.0.0.0:8880` | ntfy | Published directly (not yet behind NPM) so Seerr notifications reach phones over Tailscale/LAN; see `stacks/media/README.md` |

PostgreSQL (`5432`) and Redis (`6379`) exist only on the internal `saiprasad_backend` network. Other web apps expose ports only to the shared Docker proxy network.

Run `./scripts/ports.sh` at any time for a live port inventory. `docker compose ps` and Homepage provide complementary service views.

## Media and photos stacks

`stacks/media` and `stacks/photos` are independent Compose projects (see
`docs/MEDIA-PHOTOS-STORAGE.md`). Their apps bind directly to
`${BIND_ADDRESS}` (default `0.0.0.0`) rather than going through Nginx
Proxy Manager — reachable on the LAN and over Tailscale, never through a
router port forward.

| Host binding | Owner | Purpose |
|---|---|---|
| `8090` | qBittorrent | WebUI (moved off the default 8080, which conflicts with an existing container on this Mac) |
| `6881/tcp`, `6881/udp` | qBittorrent | Torrenting |
| `8989` | Sonarr | |
| `7878` | Radarr | |
| `9696` | Prowlarr | |
| `6767` | Bazarr | |
| `8686` | Lidarr | |
| `4533` | Navidrome | |
| `5055` | Seerr | Request UI for Jellyfin/Sonarr/Radarr; ties into Jellyfin's own accounts, no separate credential |
| `2283` | Immich server | |
| `8096`, `8920` | Jellyfin (native, not containerized) | HTTP / HTTPS |
| `7359/udp` | Jellyfin (native) | Local network discovery |
| `1900/udp` | Jellyfin (native) | DLNA |

Immich's own Postgres and Redis are not published to the host, matching
the core stack's Postgres/Redis.
