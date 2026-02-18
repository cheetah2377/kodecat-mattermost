#!/bin/sh
# Mattermost Bot Management
# Usage: /scripts/bots.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-list}"
ARG1="$2"
ARG2="$3"
ARG3="$4"

# mmctl helpers
mmctl_cmd() { /mattermost/bin/mmctl --local "$@"; }
mmctl_json() { /mattermost/bin/mmctl --local --format json "$@" 2>/dev/null; }
mmctl_quiet() { /mattermost/bin/mmctl --local --quiet "$@" 2>/dev/null; }

# Formatted output
print_header() {
    echo ""
    echo "=============================================================="
    echo "                    $1"
    echo "=============================================================="
}

print_section() {
    echo ""
    echo "-- $1 --"
}

case "$CMD" in
# LISTING
list)
    print_header "Mattermost Bots"
    if [ "$ARG1" = "--json" ]; then
        mmctl_json bot list
    else
        mmctl_cmd bot list
    fi
    ;;

active)
    print_header "Active Bots"
    mmctl_cmd bot list | grep -v "disabled" || echo "No active bots"
    ;;

disabled)
    print_header "Disabled Bots"
    mmctl_cmd bot list | grep "disabled" || echo "No disabled bots"
    ;;

# MANAGEMENT
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <bot_username>"; exit 1; }
    print_header "Bot Details: $ARG1"
    mmctl_cmd bot get "$ARG1"
    ;;

create)
    [ -z "$ARG1" ] && { echo "Usage: $0 create <username> [display_name] [description]"; exit 1; }
    USERNAME="$ARG1"
    DISPLAY_NAME="${ARG2:-$ARG1}"
    DESCRIPTION="${ARG3:-Bot created via script}"

    print_header "Create Bot"
    mmctl_cmd bot create "$USERNAME" --display-name "$DISPLAY_NAME" --description "$DESCRIPTION"
    echo ""
    echo "Bot created: $USERNAME"
    echo ""
    echo "Generate access token with:"
    echo "  $0 token $USERNAME"
    ;;

update)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 update <bot> <field> <value>"; exit 1; }
    BOT="$ARG1"
    FIELD="$ARG2"
    VALUE="$ARG3"

    print_header "Update Bot"
    case "$FIELD" in
    display-name|displayname)
        mmctl_cmd bot update "$BOT" --display-name "$VALUE"
        ;;
    description)
        mmctl_cmd bot update "$BOT" --description "$VALUE"
        ;;
    *)
        echo "Unknown field: $FIELD"
        echo "Valid fields: display-name, description"
        exit 1
        ;;
    esac
    echo "Bot $BOT updated"
    ;;

delete)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete <bot>"; exit 1; }
    print_header "Delete Bot"
    echo "WARNING: This will permanently delete bot $ARG1"
    mmctl_cmd bot delete "$ARG1" --confirm
    echo "Bot $ARG1 deleted"
    ;;

# STATUS
enable)
    [ -z "$ARG1" ] && { echo "Usage: $0 enable <bot>"; exit 1; }
    print_header "Enable Bot"
    mmctl_cmd bot enable "$ARG1"
    echo "Bot $ARG1 enabled"
    ;;

disable)
    [ -z "$ARG1" ] && { echo "Usage: $0 disable <bot>"; exit 1; }
    print_header "Disable Bot"
    mmctl_cmd bot disable "$ARG1"
    echo "Bot $ARG1 disabled"
    ;;

# TOKENS
token)
    [ -z "$ARG1" ] && { echo "Usage: $0 token <bot> [description]"; exit 1; }
    BOT="$ARG1"
    DESCRIPTION="${ARG2:-Access token for $BOT}"

    print_header "Generate Access Token"
    echo "Bot: $BOT"
    echo ""
    mmctl_cmd token generate "$BOT" "$DESCRIPTION"
    echo ""
    echo "IMPORTANT: Save this token - it cannot be retrieved later!"
    ;;

tokens)
    [ -z "$ARG1" ] && { echo "Usage: $0 tokens <bot>"; exit 1; }
    print_header "Bot Tokens: $ARG1"
    mmctl_cmd token list "$ARG1"
    ;;

token-revoke)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 token-revoke <bot> <token_id>"; exit 1; }
    print_header "Revoke Token"
    mmctl_cmd token revoke "$ARG2"
    echo "Token $ARG2 revoked"
    ;;

# OWNERSHIP
owner)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 owner <bot> <new_owner_username>"; exit 1; }
    print_header "Change Bot Owner"
    mmctl_cmd bot assign "$ARG1" "$ARG2"
    echo "Bot $ARG1 owner changed to $ARG2"
    ;;

# CONVERT
convert)
    [ -z "$ARG1" ] && { echo "Usage: $0 convert <user> [--bot|--user]"; exit 1; }
    print_header "Convert User/Bot"

    case "$ARG2" in
    --bot)
        mmctl_cmd user convert "$ARG1" --bot
        echo "User $ARG1 converted to bot"
        ;;
    --user)
        mmctl_cmd user convert "$ARG1" --user
        echo "Bot $ARG1 converted to user"
        ;;
    *)
        echo "Specify --bot or --user"
        echo "Usage: $0 convert <user> --bot"
        echo "       $0 convert <bot> --user"
        ;;
    esac
    ;;

# HELP
*)
    echo "Mattermost Bot Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list                  List all bots (default)"
    echo "  list --json           JSON output"
    echo "  active                List active bots only"
    echo "  disabled              List disabled bots"
    echo ""
    echo "MANAGEMENT:"
    echo "  get <bot>             Get bot details"
    echo "  create <username> [display_name] [description]"
    echo "                        Create new bot"
    echo "  update <bot> <field> <value>"
    echo "                        Update bot property"
    echo "  delete <bot>          Delete bot permanently"
    echo ""
    echo "STATUS:"
    echo "  enable <bot>          Enable bot"
    echo "  disable <bot>         Disable bot"
    echo ""
    echo "TOKENS:"
    echo "  token <bot> [desc]    Generate new access token"
    echo "  tokens <bot>          List bot tokens"
    echo "  token-revoke <bot> <token_id>"
    echo "                        Revoke token"
    echo ""
    echo "OWNERSHIP:"
    echo "  owner <bot> <user>    Change bot owner"
    echo ""
    echo "CONVERT:"
    echo "  convert <user> --bot  Convert user to bot"
    echo "  convert <bot> --user  Convert bot to user"
    echo ""
    echo "Bot Access Token Usage:"
    echo "  Authorization: Bearer <token>"
    echo ""
    echo "Example: Create a bot and generate token"
    echo "  $0 create mybot 'My Bot' 'Integration bot'"
    echo "  $0 token mybot 'API Access'"
    ;;
esac
