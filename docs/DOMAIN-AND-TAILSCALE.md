# saiprasad.io and Tailscale routing

## Status: implemented and verified

DNS, the wildcard certificate, and all 8 Proxy Host entries below are live
and tested — every hostname in the table returns a real HTTP response
over HTTPS (200 for reachable apps, 302 where the app itself redirects to
its own login). Two real bugs were found and fixed while setting this up
for the first time; both predate this specific session's changes:

1. **NPM's admin account had never actually been created.** Its database
   schema and migrations were fully set up, but the `user` table was
   completely empty — the container had been recreated at some point
   before the seed step ran (its default-admin creation only fires when
   `INITIAL_ADMIN_EMAIL`/`INITIAL_ADMIN_PASSWORD` env vars are set, since
   newer NPM versions otherwise expect a browser setup wizard that never
   ran here). Fixed by setting `INITIAL_ADMIN_EMAIL` (hardcoded in
   `compose.yaml`) and `INITIAL_ADMIN_PASSWORD` (`secrets.enc.env`) and
   recreating the container — NPM only acts on these while the user table
   is empty, so they're safe to leave set permanently. NPM login:
   `sai@saiprasad.io`, password in `secrets.enc.env` as
   `INITIAL_ADMIN_PASSWORD`.
2. **Speedtest Tracker's `APP_KEY` was still the literal placeholder
   text** (`base64:replace-with-speedtest-tracker-app-key`) from the very
   first `secrets.example.env` — never actually generated. This is a
   Laravel app; without a real encryption key it 500'd on every request,
   invisibly until reachability was actually tested end-to-end through
   NPM. Fixed by generating a real key
   (`openssl rand -base64 32`, prefixed `base64:`) and updating the
   secret.

Cloudflare API token (scoped to `Zone:DNS:Edit` on the `saiprasad.io`
zone only, not the Global API Key) is stored as `CLOUDFLARE_API_TOKEN` in
`secrets.enc.env`, used only for the one-time DNS-01 certificate request
via NPM's API — NPM stores its own copy of the DNS provider credentials
internally once the certificate exists, so this token isn't referenced
anywhere else in the repo.

### Media/photos apps added afterward

Four more hostnames were added once the media/photos stacks existed,
covered by the same wildcard certificate (no new cert request needed):

| Hostname | Forward host | Port | Notes |
|---|---|---:|---|
| jellyfin.home.saiprasad.io | `host.docker.internal` | 8096 | Jellyfin runs natively on macOS, not in a container — NPM reaches it via the host, not a container name |
| seerr.home.saiprasad.io | `seerr` | 5055 | |
| music.home.saiprasad.io | `navidrome` | 4533 | |
| photos.home.saiprasad.io | `immich_server` | 2283 | |

`navidrome` (in `stacks/media`) and `immich-server` (in `stacks/photos`)
are each attached to the core stack's `saiprasad_proxy` network
(`core-proxy` in their own compose files) so NPM can reach them by
container name across separate Compose projects — the same pattern
already used for Seerr's `ntfy` notifications. NPM's global
`client_max_body_size` is 2000m, comfortably covering Immich photo/video
uploads through the proxy.

Sonarr, Radarr, Prowlarr, Bazarr, Lidarr, and qBittorrent were
deliberately left on direct port access — day-to-day use goes through
Seerr, not these admin UIs directly.


## Recommended naming

Use `home.saiprasad.io` as the private application zone:

- `home.saiprasad.io` — Homepage
- `n8n.home.saiprasad.io`
- `ntfy.home.saiprasad.io`
- `speedtest.home.saiprasad.io`
- `uptime.home.saiprasad.io`
- `logs.home.saiprasad.io`
- `dockge.home.saiprasad.io`
- `proxy.home.saiprasad.io`

## DNS records

At the authoritative DNS provider for `saiprasad.io`, create:

```text
home       CNAME  <mac-mini-name>.<tailnet-name>.ts.net
*.home     CNAME  <mac-mini-name>.<tailnet-name>.ts.net
```

Use **DNS only**, not an HTTP/CDN proxy. A CNAME is only DNS indirection; traffic still goes directly to the Tailscale address returned for the Mac. Devices must be connected to your tailnet to reach it.

If the DNS provider refuses a wildcard CNAME arrangement or clients do not resolve it consistently, use the Mac's stable Tailscale IPv4 address instead:

```text
home       A  100.x.y.z
*.home     A  100.x.y.z
```

This exposes only a private CGNAT-range address in public DNS, not the service itself. A later, cleaner option is split DNS with an internal resolver.

## HTTPS

Tailscale's automatic certificates cover its own `*.ts.net` names, not `*.home.saiprasad.io`. In Nginx Proxy Manager, request a wildcard certificate for:

```text
home.saiprasad.io
*.home.saiprasad.io
```

Use a **DNS-01 challenge** with your DNS provider's narrowly scoped API token. Do not open ports 80 or 443 on the home router.

## Nginx Proxy Manager entries

For each hostname, forward to the container name and internal port on `saiprasad_proxy`:

| Hostname | Forward host | Port |
|---|---|---:|
| home.saiprasad.io | homepage | 3000 |
| n8n.home.saiprasad.io | n8n | 5678 |
| ntfy.home.saiprasad.io | ntfy | 80 |
| speedtest.home.saiprasad.io | speedtest | 80 |
| uptime.home.saiprasad.io | uptime-kuma | 3001 |
| logs.home.saiprasad.io | dozzle | 8080 |
| dockge.home.saiprasad.io | dockge | 5001 |

The NPM admin interface starts on `http://127.0.0.1:81`. Open it locally on the Mac or temporarily tunnel it over Tailscale SSH. After creating `proxy.home.saiprasad.io`, keep port 81 bound only to localhost.
