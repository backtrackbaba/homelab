# Sai's Mac mini homelab

A private, Tailscale-first container platform designed to live at:

```text
~/workspace/projects/homelab
```

## Included services

- Nginx Proxy Manager
- PostgreSQL and Redis on an internal-only network
- n8n
- ntfy
- Speedtest Tracker
- Homepage
- Uptime Kuma
- Dozzle
- Dockge

## Repository and storage layout

The Git repository contains Compose and configuration files:

```text
~/workspace/projects/homelab
```

All persistent container data stays in one separate location:

```text
/Users/sai-mini/homelab/
├── data/
└── stacks/
```

This lives under the operator's home directory because the container runtime (Colima) only
shares `$HOME` into its Linux VM by default — `/Users/Shared` is not mounted and silently
produces phantom, disconnected bind-mount directories inside the VM instead of an error.

Change `DATA_ROOT` and `STACKS_ROOT` in `.env` later if you move the data to an external SSD
(and add the new mount point to Colima's VM config, since only `$HOME` is shared today).

## Extract or clone into the expected location

```bash
mkdir -p ~/workspace/projects/homelab
cd ~/workspace/projects/homelab
unzip ~/Downloads/homelab.zip
```

The archive has no additional wrapper directory. `Makefile`, `.env.example`, and `compose.yaml` should appear directly in the current directory.

Verify with:

```bash
ls -la
make help
```

## First-time setup

```bash
cd ~/workspace/projects/homelab
make init
make install-tools
make age-key
```

Copy the public age key printed by `make age-key` into `.sops.yaml`, replacing the example recipient. Then run:

```bash
make secrets-create
make secrets-edit
make bootstrap
make up
```

Open Nginx Proxy Manager locally on the Mac mini:

```text
http://127.0.0.1:81
```

## Common commands

```bash
make help
make doctor
make up
make down
make restart
make status
make ports
make logs
make logs SERVICE=n8n
make pull
make update
make config
make secrets-edit
```

## Important initialization note

The PostgreSQL initialization script creates the n8n database only on the first startup of an empty PostgreSQL data directory. Set the final credentials using `make secrets-edit` before the first `make up`.

## Security defaults

- No router port forwarding.
- PostgreSQL and Redis have no host ports.
- Nginx Proxy Manager administration binds to localhost.
- Secrets are encrypted with SOPS and age.
- Decrypted runtime secrets are ignored by Git.
- Public DNS may name the services, while Tailscale controls network reachability.

See `docs/DOMAIN-AND-TAILSCALE.md`, `docs/SECRETS.md`, and `docs/PORTS.md`.
