#!/usr/bin/env bash
# =============================================================================
# Configuration Helpers
# =============================================================================

# Project root (relative to scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Docker compose command
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.prod.yml"
ENV_FILE="${PROJECT_ROOT}/.env.prod"
DC="docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE}"

# Load .env.prod if it exists
load_env() {
    if [ -f "${ENV_FILE}" ]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
    else
        err ".env.prod not found at ${ENV_FILE}"
        return 1
    fi
}

# Check if docker compose is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        err "Docker is not installed or not in PATH"
        return 1
    fi
    if ! docker compose version &>/dev/null; then
        err "Docker Compose v2 is required"
        return 1
    fi
}
