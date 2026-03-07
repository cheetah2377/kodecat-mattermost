# kodemeio-mattermost

Production-ready Mattermost Team Edition deployment for the kodemeio platform.

**Domain**: `chat.kodeme.io`

## Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env.prod
# Edit .env.prod with your credentials

# 2. Deploy
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

# 3. Check status
./scripts/mm-cli.sh status
```

## Architecture

| Service | Image | Purpose |
|---------|-------|---------|
| `mattermost` | Custom (extends `mattermost-team-edition:10.5`) | Chat application |
| `mm-postgres` | `postgres:16-alpine` | Database |
| `mm-backup` | Custom (Alpine + pg16-client + aws-cli) | S3 database backup |

## CLI Reference

All management commands go through `./scripts/mm-cli.sh`:

### Host Commands

```bash
mm-cli.sh status               # Service health, resource usage
mm-cli.sh logs [service] [n]   # Tail logs (all or specific service)
mm-cli.sh deploy [up|down|restart|rebuild|pull]
mm-cli.sh backup               # Trigger S3 backup
mm-cli.sh restore <s3-key>     # Restore from S3 backup
```

### Container Commands (Mattermost)

```bash
mm-cli.sh health [status|quick|json|metrics|components]
mm-cli.sh dashboard [summary|full|watch|json|activity]
mm-cli.sh users [list|get|create|activate|deactivate|reset-pwd|promote|demote|...]
mm-cli.sh teams [list|create|archive|members|add|remove|...]
mm-cli.sh channels [list|create|archive|members|add|remove|...]
mm-cli.sh permissions [list|get|add|remove|assign|...]
mm-cli.sh posts [search|get|delete|pin|unpin|...]
mm-cli.sh config [get|set|show|export|test-email|...]
mm-cli.sh maintenance [cleanup|optimize|reset-caches|...]
mm-cli.sh webhooks [list|create|delete|...]
mm-cli.sh bots [list|create|enable|disable|...]
mm-cli.sh plugins [list|install|enable|disable|...]
mm-cli.sh integrations [oauth-list|ldap-sync|...]
mm-cli.sh jobs [list|status|...]
mm-cli.sh audit [login|security|compliance|...]
mm-cli.sh import-export [export|import|...]
```

### Examples

```bash
# Check system health
./scripts/mm-cli.sh health quick

# List all users
./scripts/mm-cli.sh users list --all

# Create a new team
./scripts/mm-cli.sh teams create my-team "My Team"

# Create a private channel
./scripts/mm-cli.sh channels create my-team general "General" --private

# Promote user to admin
./scripts/mm-cli.sh users promote john.doe

# Trigger manual backup
./scripts/mm-cli.sh backup

# View mattermost logs
./scripts/mm-cli.sh logs mattermost 200
```

## Environment Setup

### Required Credentials

| Variable | Source | Notes |
|----------|--------|-------|
| `MM_POSTGRESQL_PASSWORD` | `openssl rand -base64 32` | Auto-generated |
| `AUTHENTIK_MATTERMOST_CLIENT_ID` | Authentik admin panel | OAuth2 provider |
| `AUTHENTIK_MATTERMOST_CLIENT_SECRET` | Authentik admin panel | OAuth2 provider |
| `MM_FILESETTINGS_AMAZONS3*` | Hetzner console | File storage |
| `S3_BACKUP_*` | Hetzner console | Database backup |
| `MM_EMAILSETTINGS_SMTPPASSWORD` | Mailcow admin | Email notifications |

### Resource Limits

All resource limits are configurable via environment variables:

| Variable | Default | Service |
|----------|---------|---------|
| `CPU_LIMIT_MM` | 2 | Mattermost |
| `MEMORY_LIMIT_MM` | 2G | Mattermost |
| `CPU_LIMIT_DB` | 1 | PostgreSQL |
| `MEMORY_LIMIT_DB` | 1G | PostgreSQL |
| `CPU_LIMIT_BACKUP` | 0.25 | Backup |
| `MEMORY_LIMIT_BACKUP` | 128M | Backup |

## Development

```bash
make test    # Run validation tests
make lint    # Run linters
```
