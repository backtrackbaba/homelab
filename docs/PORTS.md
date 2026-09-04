# Port policy

Only the reverse proxy publishes application traffic to the Mac:

| Host binding | Owner | Purpose |
|---|---|---|
| `0.0.0.0:80` | Nginx Proxy Manager | HTTP / redirects |
| `0.0.0.0:443` | Nginx Proxy Manager | HTTPS gateway |
| `127.0.0.1:81` | Nginx Proxy Manager | Initial/local administration |

PostgreSQL (`5432`) and Redis (`6379`) exist only on the internal `saiprasad_backend` network. Other web apps expose ports only to the shared Docker proxy network.

Run `./scripts/ports.sh` at any time for a live port inventory. `docker compose ps` and Homepage provide complementary service views.
