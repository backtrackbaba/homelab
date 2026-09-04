# saiprasad.io and Tailscale routing

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
