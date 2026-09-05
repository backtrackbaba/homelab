# Vaultwarden

Self-hosted password manager (Bitwarden-compatible). Part of the core
stack (`compose.yaml`), reachable at `https://vault.home.saiprasad.io`
or `http://<tailscale-IP>:8222` directly.

## Access model

Tailscale-only for now, same as everything else in this repo — every
device that needs the vault (phone, laptop) needs the Tailscale app
installed and signed into this tailnet. No public exposure.

If that stops being sufficient later (a device that can't/won't run
Tailscale needs access), the lower-risk upgrade path is **Tailscale
Funnel** scoped to just this one service — it doesn't require changing
how Vaultwarden itself is deployed. Do not open a router port or add
broader public exposure without that being a separate, explicit
decision.

## First-run setup — do this once, then lock signups down

`SIGNUPS_ALLOWED=true` is set so the first (and only) account can be
created through the normal web UI at `https://vault.home.saiprasad.io/#/register`.
Once that account exists:

1. Edit `compose.yaml`, set `SIGNUPS_ALLOWED: "false"` on the
   `vaultwarden` service.
2. `docker compose up -d vaultwarden` to apply it.

Leaving signups open indefinitely is unnecessary risk for a
single-user instance reachable by anyone who can reach `8222`/the proxy
host, even on a private tailnet.

## Admin panel

`ADMIN_TOKEN` (stored as `VAULTWARDEN_ADMIN_TOKEN` in `secrets.enc.env`)
unlocks `https://vault.home.saiprasad.io/admin` — diagnostics, user
management, org settings. Not needed for day-to-day use.
