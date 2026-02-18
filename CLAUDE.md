# kodemeio-mattermost

Production Docker deployment for Mattermost Team Edition (chat.kodeme.io).
Deployed to Dokploy with Traefik reverse proxy (HTTPS).

## Architecture

```
                     dokploy-network (external)
                           |
                Traefik (HTTPS + Let's Encrypt)
                           |
                     mattermost:8065
                     (custom Dockerfile)
                           |
            +--------------+--------------+
            |                             |
        mm-postgres                   mm-backup
        (postgres:16-alpine)          (S3 pg_dump sidecar)
            |                             |
            +-------------+---------------+
                          |
                  mm-internal (isolated bridge)
```

- **mattermost**: Mattermost Team Edition 10.5 on port 8065 (Traefik routes HTTPS)
- **mm-postgres**: PostgreSQL 16 Alpine (persistent database)
- **mm-backup**: S3 backup service (pg_dump to Hetzner Object Storage)

## Project Structure

```
docker-compose.prod.yml          # Production compose (Dokploy entry point)
.env.prod                        # Production secrets (gitignored)
.env.example                     # Environment template
.gitignore                       # Git ignore rules
Dockerfile                       # Extends mattermost-team-edition, COPY scripts
backup/
  Dockerfile                     # S3 backup container (alpine + pg16-client + aws-cli)
  backup.sh                      # S3 backup/restore script
scripts/
  mm-cli.sh                      # Main CLI entry point (dispatches all commands)
  lib/common.sh                  # Shared utilities (colors, logging)
  lib/config.sh                  # Configuration helpers (DC command, load_env)
  status.sh                      # Host: check service health
  logs.sh                        # Host: tail service logs
  deploy.sh                      # Host: deploy/redeploy
  health.sh                      # Container: health check with 0-100 scoring
  dashboard.sh                   # Container: real-time system dashboard
  users.sh                       # Container: user lifecycle management
  teams.sh                       # Container: team management
  channels.sh                    # Container: channel management
  permissions.sh                 # Container: role/permission management
  posts.sh                       # Container: post/message management
  config.sh                      # Container: configuration management
  maintenance.sh                 # Container: cleanup/maintenance
  webhooks.sh                    # Container: webhook management
  bots.sh                        # Container: bot management
  plugins.sh                     # Container: plugin management
  integrations.sh                # Container: LDAP/SAML/OAuth
  jobs.sh                        # Container: background job monitoring
  audit.sh                       # Container: audit/compliance logs
  import-export.sh               # Container: bulk import/export
```

## Networks

- `dokploy-network` (external) — Traefik routing, shared across Dokploy services
- `mm-internal` (bridge) — Isolated network for postgres and backup (not exposed)

## Volumes

- `mm-postgres-data` — PostgreSQL data directory
- `mm-config` — Mattermost configuration
- `mm-data` — Mattermost data (file uploads when using local storage)
- `mm-logs` — Mattermost logs
- `mm-plugins` — Server plugins
- `mm-client-plugins` — Client plugins
- `mm-bleve-indexes` — Full-text search indexes

## Deployment

```bash
# Start all services
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

# View logs
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f

# Check health
docker compose -f docker-compose.prod.yml --env-file .env.prod ps

# CLI
./scripts/mm-cli.sh status
./scripts/mm-cli.sh logs
./scripts/mm-cli.sh deploy
./scripts/mm-cli.sh health
./scripts/mm-cli.sh users list --all
./scripts/mm-cli.sh backup
```

## Traefik Routing

Routing is configured in Dokploy UI (Service -> Advanced -> Traefik).

| Router | Rule | Port | Notes |
|--------|------|------|-------|
| `mattermost` | `Host(\`chat.kodeme.io\`)` | 8065 | Main chat UI + API |

## Environment Variables

| Section | Variables | Notes |
|---------|-----------|-------|
| PostgreSQL | `MM_POSTGRESQL_USER`, `MM_POSTGRESQL_PASSWORD` | Internal service |
| Authentik | `AUTHENTIK_URL`, `AUTHENTIK_MATTERMOST_CLIENT_ID/SECRET` | SSO via GitLab provider |
| File Storage | `MM_FILESETTINGS_AMAZONS3*` | Hetzner Object Storage |
| Email | `MM_EMAILSETTINGS_SMTP*` | Mailcow |
| S3 Backup | `S3_BACKUP_ENDPOINT`, `S3_BACKUP_ACCESS_KEY/SECRET_KEY` | Database backups |
| Resources | `CPU_LIMIT_MM`, `MEMORY_LIMIT_MM`, etc. | Configurable limits |

## Resource Allocation

| Service | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|---------|-----------|-------------|-------------|-----------------|
| mattermost | 2.0 | 2G | 0.5 | 512M |
| mm-postgres | 1.0 | 1G | 0.25 | 256M |
| mm-backup | 0.25 | 128M | 0.1 | 64M |

## Monitoring Labels

```yaml
- "logging=promtail"
- "app=mattermost"
- "app.tenant=kodemeio"
- "app.component=web"       # web, database, backup
- "app.service=mattermost-web"
```

Loki queries:
```logql
{app="mattermost"} |= "ERROR"
{app="mattermost", app_component="web"} | json
{app="mattermost", app_component="database"}
```

## Server Info

- **Domain**: chat.kodeme.io (via Traefik)
- **Image**: mattermost/mattermost-team-edition:10.5 (custom Dockerfile)
- **PostgreSQL**: postgres:16-alpine (internal)
- **Backup**: Hetzner Object Storage (S3-compatible)
- **SSO**: Authentik (OAuth2 via GitLab provider)

## Rules for Claude

- Always use `docker compose -f docker-compose.prod.yml --env-file .env.prod` for compose commands
- Scripts are baked into the Mattermost Docker image via `COPY scripts/ /scripts/` (no bind mounts)
- Container scripts run inside the mattermost container via `docker exec -it <container> /bin/sh /scripts/<script>.sh`
- Host scripts run locally and use `lib/config.sh` for the DC command
- `mm-cli.sh` is the single entry point — dispatches to both host and container scripts
- PostgreSQL credentials are in `.env.prod`, never hardcode them
- The `.env.prod` is gitignored; `.env.example` is the template
- Backup uses separate S3 credentials (`S3_BACKUP_*`) from file storage (`MM_FILESETTINGS_AMAZONS3*`)
- Service names in compose: `mm-postgres`, `mattermost`, `mm-backup`
