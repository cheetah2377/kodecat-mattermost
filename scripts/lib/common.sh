#!/usr/bin/env bash
# =============================================================================
# Shared Utilities — Colors, logging, helpers
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Logging
log()  { echo -e "${BLUE}[INFO]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Require environment variable to be set
require_env() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        err "Required environment variable ${var_name} is not set"
        return 1
    fi
}

# Confirm destructive operation
confirm() {
    local msg="${1:-Are you sure?}"
    echo -en "${YELLOW}${msg} [y/N]${RESET} "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}
