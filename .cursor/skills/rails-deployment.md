# Rails Deployment

ugo ships as a Docker image (`ghcr.io/fdocr/ugo`) for [Once](https://github.com/basecamp/once) or any container runtime. Thruster sits in front of Puma inside the container.

## Architecture

```
Internet (optional CDN e.g. Cloudflare)
    │
    ▼
Once edge proxy (SSL, zero-downtime deploys)
    │
    ▼
Docker container
    Thruster (HTTP/2, port 80)
        │
        ▼
    Puma (Rails)
        ├── Solid Queue
        ├── Solid Cache
        └── SQLite under /rails/storage/
```

## Dockerfile

- Production image: `docker build -t ugo .`
- Default CMD: `./bin/thrust ./bin/rails server` (Thruster → Puma)
- Health check: `GET /up`
- Persistent data: `/rails/storage/` (Once mounts this volume)
- Backup hooks: `/hooks/pre-backup`, `/hooks/post-restore`

## Once operator commands

```bash
curl https://get.once.com | sh          # Install Once; choose ghcr.io/fdocr/ugo
once                                   # Dashboard TUI
once update                            # Pull latest image
once backup                            # Trigger backup
docker exec -it <id> bin/rails console
docker exec -it <id> bin/rails trusted_proxies:cloudflare   # CDN CIDR helper
```

Custom env vars: Once → select app → **`s`** Settings → **`v`** Environment → Done (redeploys).

| Variable | Default | Role |
|----------|---------|------|
| `WEB_CONCURRENCY` | `1` | Puma workers |
| `RAILS_MAX_THREADS` | `3` | Puma threads per worker |
| `JOB_CONCURRENCY` | `1` | Solid Queue `processes` |
| `SOLID_QUEUE_THREADS` | `3` | Solid Queue `threads` |
| `DB_POOL` | auto | Per-process AR pool (`max` of thread vars) |
| `TRUSTED_PROXIES_EXTRA` | unset | CDN CIDRs (orange cloud) |

See [docs/self-hosting.md](../../docs/self-hosting.md) for Cloudflare and concurrency walkthroughs.

## Production security initializers

- `config/initializers/trusted_proxies.rb` — `TRUSTED_PROXIES_EXTRA` CIDRs
- `config/initializers/host_authorization.rb` — `AppConfig#app_domain` host allowlist; `/up` excluded

## Local / CI

```bash
bin/rails test
bin/rubocop
bin/brakeman
```

No Kamal deploy config in this repo; production targeting is Once + GHCR.
