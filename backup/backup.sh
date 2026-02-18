#!/usr/bin/env bash
# =============================================================================
# Mattermost S3 Backup — pg_dump to Hetzner Object Storage
# =============================================================================
# Runs on a configurable schedule (BACKUP_INTERVAL, default 86400s = daily).
# Supports backup, restore, and retention management.
#
# Environment variables:
#   PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE — PostgreSQL connection
#   S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET, S3_REGION — S3
#   BACKUP_INTERVAL — seconds between backups (default: 86400)
#   BACKUP_RETENTION_DAILY — keep last N daily backups (default: 7)
#   BACKUP_RETENTION_WEEKLY — keep last N weekly backups (default: 4)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BACKUP_INTERVAL="${BACKUP_INTERVAL:-86400}"
RETENTION_DAILY="${BACKUP_RETENTION_DAILY:-7}"
RETENTION_WEEKLY="${BACKUP_RETENTION_WEEKLY:-4}"
S3_PREFIX="s3://${S3_BUCKET}/mattermost"
TIMESTAMP_FMT="%Y%m%d-%H%M%S"

# Configure AWS CLI for S3-compatible storage
export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"
S3_ARGS="--endpoint-url ${S3_ENDPOINT}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"; }
err() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Wait for PostgreSQL
# ---------------------------------------------------------------------------
wait_for_db() {
    local retries=30
    local delay=5
    for i in $(seq 1 "$retries"); do
        if pg_isready -q; then
            log "PostgreSQL is ready"
            return 0
        fi
        log "Waiting for PostgreSQL... ($i/$retries)"
        sleep "$delay"
    done
    err "PostgreSQL not available after $retries attempts"
    return 1
}

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
do_backup() {
    local timestamp
    timestamp=$(date +"$TIMESTAMP_FMT")
    local filename="mattermost-${timestamp}.sql.gz"
    local tmpfile="/tmp/${filename}"

    log "Starting backup: ${filename}"

    # pg_dump with compression
    if ! pg_dump --no-owner --no-privileges | gzip > "${tmpfile}"; then
        err "pg_dump failed"
        rm -f "${tmpfile}"
        return 1
    fi

    local size
    size=$(du -h "${tmpfile}" | cut -f1)
    log "Dump complete: ${filename} (${size})"

    # Upload to S3
    # shellcheck disable=SC2086
    if ! aws s3 cp "${tmpfile}" "${S3_PREFIX}/daily/${filename}" ${S3_ARGS}; then
        err "S3 upload failed"
        rm -f "${tmpfile}"
        return 1
    fi

    log "Uploaded to ${S3_PREFIX}/daily/${filename}"

    # Weekly backup (on Sundays)
    if [ "$(date +%u)" = "7" ]; then
        # shellcheck disable=SC2086
        aws s3 cp "${tmpfile}" "${S3_PREFIX}/weekly/${filename}" ${S3_ARGS}
        log "Weekly backup: ${S3_PREFIX}/weekly/${filename}"
    fi

    rm -f "${tmpfile}"
    log "Backup complete: ${filename}"
}

# ---------------------------------------------------------------------------
# Retention cleanup
# ---------------------------------------------------------------------------
do_cleanup() {
    log "Running retention cleanup..."

    # List daily backups, sort, and remove old ones
    # shellcheck disable=SC2086
    local daily_count
    daily_count=$(aws s3 ls "${S3_PREFIX}/daily/" ${S3_ARGS} 2>/dev/null | wc -l || echo "0")

    if [ "$daily_count" -gt "$RETENTION_DAILY" ]; then
        local to_remove=$((daily_count - RETENTION_DAILY))
        log "Removing ${to_remove} old daily backup(s) (keeping ${RETENTION_DAILY})"
        # shellcheck disable=SC2086
        aws s3 ls "${S3_PREFIX}/daily/" ${S3_ARGS} | sort | head -n "${to_remove}" | while read -r _ _ _ key; do
            # shellcheck disable=SC2086
            aws s3 rm "${S3_PREFIX}/daily/${key}" ${S3_ARGS}
            log "Removed: daily/${key}"
        done
    fi

    # Weekly retention
    # shellcheck disable=SC2086
    local weekly_count
    weekly_count=$(aws s3 ls "${S3_PREFIX}/weekly/" ${S3_ARGS} 2>/dev/null | wc -l || echo "0")

    if [ "$weekly_count" -gt "$RETENTION_WEEKLY" ]; then
        local to_remove=$((weekly_count - RETENTION_WEEKLY))
        log "Removing ${to_remove} old weekly backup(s) (keeping ${RETENTION_WEEKLY})"
        # shellcheck disable=SC2086
        aws s3 ls "${S3_PREFIX}/weekly/" ${S3_ARGS} | sort | head -n "${to_remove}" | while read -r _ _ _ key; do
            # shellcheck disable=SC2086
            aws s3 rm "${S3_PREFIX}/weekly/${key}" ${S3_ARGS}
            log "Removed: weekly/${key}"
        done
    fi

    log "Retention cleanup complete"
}

# ---------------------------------------------------------------------------
# Restore (called manually via docker exec)
# ---------------------------------------------------------------------------
do_restore() {
    local s3_path="${1:-}"
    if [ -z "$s3_path" ]; then
        log "Available backups:"
        # shellcheck disable=SC2086
        aws s3 ls "${S3_PREFIX}/daily/" ${S3_ARGS} 2>/dev/null || true
        # shellcheck disable=SC2086
        aws s3 ls "${S3_PREFIX}/weekly/" ${S3_ARGS} 2>/dev/null || true
        err "Usage: backup.sh restore <s3-key>"
        err "Example: backup.sh restore daily/mattermost-20250101-120000.sql.gz"
        return 1
    fi

    local tmpfile="/tmp/restore.sql.gz"

    log "Downloading: ${S3_PREFIX}/${s3_path}"
    # shellcheck disable=SC2086
    if ! aws s3 cp "${S3_PREFIX}/${s3_path}" "${tmpfile}" ${S3_ARGS}; then
        err "Download failed"
        return 1
    fi

    log "Restoring database..."
    if ! gunzip -c "${tmpfile}" | psql --single-transaction; then
        err "Restore failed"
        rm -f "${tmpfile}"
        return 1
    fi

    rm -f "${tmpfile}"
    log "Restore complete from: ${s3_path}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-}" in
    restore)
        wait_for_db
        do_restore "${2:-}"
        ;;
    backup)
        wait_for_db
        do_backup
        do_cleanup
        ;;
    *)
        # Default: scheduled backup loop
        wait_for_db
        log "Starting backup scheduler (interval: ${BACKUP_INTERVAL}s)"
        log "Retention: ${RETENTION_DAILY} daily, ${RETENTION_WEEKLY} weekly"

        # Run initial backup on start
        do_backup
        do_cleanup

        while true; do
            sleep "$BACKUP_INTERVAL"
            do_backup
            do_cleanup
        done
        ;;
esac
