#!/bin/sh
# Mattermost Team Management
# Usage: /scripts/teams.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-list}"
ARG1="$2"
ARG2="$3"
ARG3="$4"
ARG4="$5"

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
    print_header "Mattermost Teams"
    if [ "$ARG1" = "--json" ]; then
        mmctl_json team list
    elif [ "$ARG1" = "--deleted" ]; then
        mmctl_cmd team list --all
    else
        mmctl_cmd team list
    fi
    ;;

stats)
    print_header "Team Statistics"
    TOTAL=$(mmctl_json team list 2>/dev/null | grep -c '"id":' || echo "0")
    echo ""
    echo "Total Teams: $TOTAL"
    echo ""
    echo "Team Details:"
    mmctl_cmd team list
    ;;

# LOOKUP
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <team_id|team_name>"; exit 1; }
    print_header "Team Details"
    mmctl_cmd team get "$ARG1"
    ;;

search)
    [ -z "$ARG1" ] && { echo "Usage: $0 search <term>"; exit 1; }
    print_header "Search Results: $ARG1"
    mmctl_cmd team search "$ARG1"
    ;;

# CREATION
create)
    [ -z "$ARG1" ] && { echo "Usage: $0 create <name> [display_name] [--private]"; exit 1; }
    NAME="$ARG1"
    DISPLAY_NAME="${ARG2:-$ARG1}"

    print_header "Create Team"
    echo "Name: $NAME"
    echo "Display Name: $DISPLAY_NAME"

    if [ "$ARG2" = "--private" ] || [ "$ARG3" = "--private" ]; then
        mmctl_cmd team create --name "$NAME" --display-name "$DISPLAY_NAME" --private
        echo "Private team created"
    else
        mmctl_cmd team create --name "$NAME" --display-name "$DISPLAY_NAME"
        echo "Open team created"
    fi
    ;;

# MODIFICATION
rename)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 rename <team> <new_name>"; exit 1; }
    print_header "Rename Team"
    mmctl_cmd team rename "$ARG1" --name "$ARG2"
    echo "Team renamed to $ARG2"
    ;;

set-display)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-display <team> <display_name>"; exit 1; }
    print_header "Set Display Name"
    mmctl_cmd team rename "$ARG1" --display-name "$ARG2"
    echo "Display name set to: $ARG2"
    ;;

set-description)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-description <team> <description>"; exit 1; }
    print_header "Set Description"
    mmctl_cmd team modify "$ARG1" --description "$ARG2"
    echo "Description updated"
    ;;

make-public)
    [ -z "$ARG1" ] && { echo "Usage: $0 make-public <team>"; exit 1; }
    print_header "Convert to Open Team"
    mmctl_cmd team modify "$ARG1" --public
    echo "Team $ARG1 is now open (public)"
    ;;

make-private)
    [ -z "$ARG1" ] && { echo "Usage: $0 make-private <team>"; exit 1; }
    print_header "Convert to Invite-Only Team"
    mmctl_cmd team modify "$ARG1" --private
    echo "Team $ARG1 is now invite-only (private)"
    ;;

# STATUS
archive)
    [ -z "$ARG1" ] && { echo "Usage: $0 archive <team>"; exit 1; }
    print_header "Archive Team"
    mmctl_cmd team archive "$ARG1"
    echo "Team $ARG1 archived"
    ;;

restore)
    [ -z "$ARG1" ] && { echo "Usage: $0 restore <team>"; exit 1; }
    print_header "Restore Archived Team"
    mmctl_cmd team restore "$ARG1"
    echo "Team $ARG1 restored"
    ;;

delete)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete <team>"; exit 1; }
    print_header "Delete Team (Permanent)"
    echo "WARNING: This will permanently delete team $ARG1"
    echo "All channels and posts will be deleted!"
    echo ""
    echo "Proceeding with deletion..."
    mmctl_cmd team delete "$ARG1" --confirm
    echo "Team $ARG1 deleted"
    ;;

# MEMBERS
members)
    [ -z "$ARG1" ] && { echo "Usage: $0 members <team> [page|--all]"; exit 1; }
    print_header "Team Members: $ARG1"
    if [ "$ARG2" = "--all" ]; then
        mmctl_cmd team users list "$ARG1" --all
    else
        PAGE="${ARG2:-0}"
        mmctl_cmd team users list "$ARG1" --page "$PAGE" --per-page 50
    fi
    ;;

add)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 add <team> <user>"; exit 1; }
    print_header "Add Member to Team"
    mmctl_cmd team users add "$ARG1" "$ARG2"
    echo "User $ARG2 added to team $ARG1"
    ;;

add-many)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 add-many <team> <user1,user2,...>"; exit 1; }
    print_header "Add Multiple Members"
    IFS=',' read -r -a USERS <<< "$ARG2" 2>/dev/null || USERS=$(echo "$ARG2" | tr ',' ' ')
    for USER in $USERS; do
        mmctl_cmd team users add "$ARG1" "$USER" && echo "Added: $USER" || echo "Failed: $USER"
    done
    echo "Done adding users to $ARG1"
    ;;

remove)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 remove <team> <user>"; exit 1; }
    print_header "Remove Member from Team"
    mmctl_cmd team users remove "$ARG1" "$ARG2"
    echo "User $ARG2 removed from team $ARG1"
    ;;

role)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 role <team> <user> <admin|member>"; exit 1; }
    print_header "Set Team Role"
    case "$ARG3" in
    admin)
        mmctl_cmd team users add "$ARG1" "$ARG2" --team-admin
        echo "User $ARG2 set as team admin in $ARG1"
        ;;
    member)
        # Remove and re-add as regular member
        mmctl_cmd team users remove "$ARG1" "$ARG2" 2>/dev/null || true
        mmctl_cmd team users add "$ARG1" "$ARG2"
        echo "User $ARG2 set as member in $ARG1"
        ;;
    *)
        echo "Role must be 'admin' or 'member'"
        exit 1
        ;;
    esac
    ;;

# INVITES
invite-link)
    [ -z "$ARG1" ] && { echo "Usage: $0 invite-link <team> [--regenerate|--disable]"; exit 1; }
    print_header "Team Invite Link"

    case "$ARG2" in
    --regenerate)
        mmctl_cmd team modify "$ARG1" --invite-id reset
        echo "Invite link regenerated"
        ;;
    --disable)
        mmctl_cmd team modify "$ARG1" --invite-id ""
        echo "Invite link disabled"
        ;;
    *)
        # Get/show invite link
        mmctl_cmd team get "$ARG1" | grep -i invite || echo "Check team settings for invite link"
        ;;
    esac
    ;;

# HELP
*)
    echo "Mattermost Team Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list                  List all teams (default)"
    echo "  list --deleted        Include deleted teams"
    echo "  stats                 Team statistics summary"
    echo ""
    echo "LOOKUP:"
    echo "  get <team>            Get team by ID or name"
    echo "  search <term>         Search teams"
    echo ""
    echo "CREATION:"
    echo "  create <name> [display] [--private]   Create team"
    echo ""
    echo "MODIFICATION:"
    echo "  rename <team> <new_name>        Rename team"
    echo "  set-display <team> <display>    Set display name"
    echo "  set-description <team> <desc>   Set description"
    echo "  make-public <team>              Convert to open team"
    echo "  make-private <team>             Convert to invite-only"
    echo ""
    echo "STATUS:"
    echo "  archive <team>        Archive team"
    echo "  restore <team>        Restore archived team"
    echo "  delete <team>         Permanently delete"
    echo ""
    echo "MEMBERS:"
    echo "  members <team> [page|--all]   List team members"
    echo "  add <team> <user>             Add member"
    echo "  add-many <team> <u1,u2,...>   Add multiple members"
    echo "  remove <team> <user>          Remove member"
    echo "  role <team> <user> admin      Set as team admin"
    echo "  role <team> <user> member     Set as regular member"
    echo ""
    echo "INVITES:"
    echo "  invite-link <team>              Get/create invite link"
    echo "  invite-link <team> --regenerate Regenerate invite link"
    echo "  invite-link <team> --disable    Disable invite link"
    ;;
esac
