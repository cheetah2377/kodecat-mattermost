#!/bin/sh
# Mattermost Channel Management
# Usage: /scripts/channels.sh [command] [args]
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
    [ -z "$ARG1" ] && { echo "Usage: $0 list <team> [--all|--deleted]"; exit 1; }
    print_header "Channels in $ARG1"
    if [ "$ARG2" = "--all" ]; then
        mmctl_cmd channel list "$ARG1" --all
    elif [ "$ARG2" = "--deleted" ]; then
        mmctl_cmd channel list "$ARG1" --all
    elif [ "$ARG2" = "--json" ]; then
        mmctl_json channel list "$ARG1"
    else
        mmctl_cmd channel list "$ARG1"
    fi
    ;;

public)
    [ -z "$ARG1" ] && { echo "Usage: $0 public <team>"; exit 1; }
    print_header "Public Channels in $ARG1"
    mmctl_cmd channel list "$ARG1" --public
    ;;

private)
    [ -z "$ARG1" ] && { echo "Usage: $0 private <team>"; exit 1; }
    print_header "Private Channels in $ARG1"
    mmctl_cmd channel list "$ARG1" --private
    ;;

dm)
    print_header "Direct Message Channels"
    echo "Direct message channels are user-specific"
    echo "Use mmctl channel list with user context"
    ;;

group-dm)
    print_header "Group DM Channels"
    echo "Group DM channels are user-specific"
    echo "Use mmctl channel list with user context"
    ;;

# LOOKUP
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <channel_id>"; exit 1; }
    print_header "Channel Details"
    mmctl_cmd channel get "$ARG1"
    ;;

get-by-name)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 get-by-name <team> <channel_name>"; exit 1; }
    print_header "Channel Details"
    mmctl_cmd channel get "$ARG1:$ARG2"
    ;;

search)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 search <team> <term>"; exit 1; }
    print_header "Search Results in $ARG1: $ARG2"
    mmctl_cmd channel search "$ARG1" "$ARG2"
    ;;

# CREATION
create)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 create <team> <name> [display_name] [--private]"; exit 1; }
    TEAM="$ARG1"
    NAME="$ARG2"
    DISPLAY_NAME="${ARG3:-$ARG2}"

    print_header "Create Channel"
    echo "Team: $TEAM"
    echo "Name: $NAME"
    echo "Display Name: $DISPLAY_NAME"

    if [ "$ARG3" = "--private" ] || [ "$ARG4" = "--private" ]; then
        mmctl_cmd channel create --team "$TEAM" --name "$NAME" --display-name "$DISPLAY_NAME" --private
        echo "Private channel created"
    else
        mmctl_cmd channel create --team "$TEAM" --name "$NAME" --display-name "$DISPLAY_NAME"
        echo "Public channel created"
    fi
    ;;

create-group)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 create-group <team> <name> <user1,user2,...>"; exit 1; }
    TEAM="$ARG1"
    NAME="$ARG2"
    USERS="$ARG3"

    print_header "Create Group Channel"
    # Create private channel first
    mmctl_cmd channel create --team "$TEAM" --name "$NAME" --display-name "$NAME" --private

    # Add users
    echo "Adding users..."
    IFS=',' read -r USERLIST <<< "$USERS" 2>/dev/null || USERLIST=$(echo "$USERS" | tr ',' ' ')
    for USER in $USERLIST; do
        mmctl_cmd channel users add "$TEAM:$NAME" "$USER" 2>/dev/null && echo "Added: $USER" || echo "Failed: $USER"
    done
    echo "Group channel created"
    ;;

# MODIFICATION
rename)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 rename <channel> <new_name>"; exit 1; }
    print_header "Rename Channel"
    mmctl_cmd channel rename "$ARG1" --name "$ARG2"
    echo "Channel renamed to $ARG2"
    ;;

set-header)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-header <channel> <header>"; exit 1; }
    print_header "Set Channel Header"
    mmctl_cmd channel modify "$ARG1" --header "$ARG2"
    echo "Header updated"
    ;;

set-purpose)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-purpose <channel> <purpose>"; exit 1; }
    print_header "Set Channel Purpose"
    mmctl_cmd channel modify "$ARG1" --purpose "$ARG2"
    echo "Purpose updated"
    ;;

make-private)
    [ -z "$ARG1" ] && { echo "Usage: $0 make-private <channel>"; exit 1; }
    print_header "Convert to Private"
    mmctl_cmd channel modify "$ARG1" --private
    echo "Channel $ARG1 is now private"
    ;;

make-public)
    [ -z "$ARG1" ] && { echo "Usage: $0 make-public <channel>"; exit 1; }
    print_header "Convert to Public"
    mmctl_cmd channel modify "$ARG1" --public
    echo "Channel $ARG1 is now public"
    ;;

move)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 move <channel> <new_team>"; exit 1; }
    print_header "Move Channel"
    mmctl_cmd channel move "$ARG2" "$ARG1"
    echo "Channel $ARG1 moved to $ARG2"
    ;;

# STATUS
archive)
    [ -z "$ARG1" ] && { echo "Usage: $0 archive <channel>"; exit 1; }
    print_header "Archive Channel"
    mmctl_cmd channel archive "$ARG1"
    echo "Channel $ARG1 archived"
    ;;

restore)
    [ -z "$ARG1" ] && { echo "Usage: $0 restore <channel>"; exit 1; }
    print_header "Restore Archived Channel"
    mmctl_cmd channel unarchive "$ARG1"
    echo "Channel $ARG1 restored"
    ;;

delete)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete <channel> [--permanent]"; exit 1; }
    print_header "Delete Channel"

    if [ "$ARG2" = "--permanent" ]; then
        echo "WARNING: Permanent deletion of $ARG1"
        echo "All messages will be lost!"
        mmctl_cmd channel delete "$ARG1" --confirm
        echo "Channel $ARG1 permanently deleted"
    else
        mmctl_cmd channel archive "$ARG1"
        echo "Channel $ARG1 archived (soft delete)"
        echo "Use --permanent for hard delete"
    fi
    ;;

# MEMBERS
members)
    [ -z "$ARG1" ] && { echo "Usage: $0 members <channel> [page|--all]"; exit 1; }
    print_header "Channel Members: $ARG1"
    if [ "$ARG2" = "--all" ]; then
        mmctl_cmd channel users list "$ARG1" --all
    else
        PAGE="${ARG2:-0}"
        mmctl_cmd channel users list "$ARG1" --page "$PAGE" --per-page 50
    fi
    ;;

add)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 add <channel> <user>"; exit 1; }
    print_header "Add Member to Channel"
    mmctl_cmd channel users add "$ARG1" "$ARG2"
    echo "User $ARG2 added to channel $ARG1"
    ;;

add-many)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 add-many <channel> <user1,user2,...>"; exit 1; }
    print_header "Add Multiple Members"
    IFS=',' read -r USERS <<< "$ARG2" 2>/dev/null || USERS=$(echo "$ARG2" | tr ',' ' ')
    for USER in $USERS; do
        mmctl_cmd channel users add "$ARG1" "$USER" 2>/dev/null && echo "Added: $USER" || echo "Failed: $USER"
    done
    echo "Done adding users to $ARG1"
    ;;

remove)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 remove <channel> <user>"; exit 1; }
    print_header "Remove Member from Channel"
    mmctl_cmd channel users remove "$ARG1" "$ARG2"
    echo "User $ARG2 removed from channel $ARG1"
    ;;

role)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 role <channel> <user> <admin|member>"; exit 1; }
    print_header "Set Channel Role"
    case "$ARG3" in
    admin)
        mmctl_cmd channel users add "$ARG1" "$ARG2" --channel-admin
        echo "User $ARG2 set as channel admin"
        ;;
    member)
        mmctl_cmd channel users remove "$ARG1" "$ARG2" 2>/dev/null || true
        mmctl_cmd channel users add "$ARG1" "$ARG2"
        echo "User $ARG2 set as channel member"
        ;;
    *)
        echo "Role must be 'admin' or 'member'"
        exit 1
        ;;
    esac
    ;;

# STATISTICS
stats)
    [ -z "$ARG1" ] && { echo "Usage: $0 stats <channel|team>"; exit 1; }
    print_header "Channel Statistics"

    # Try to get channel stats first
    mmctl_cmd channel get "$ARG1" 2>/dev/null || {
        # If not a channel, assume it's a team
        echo "Channels in team $ARG1:"
        PUBLIC=$(mmctl_json channel list "$ARG1" --public 2>/dev/null | grep -c '"id":' || echo "0")
        PRIVATE=$(mmctl_json channel list "$ARG1" --private 2>/dev/null | grep -c '"id":' || echo "0")
        TOTAL=$((PUBLIC + PRIVATE))

        echo ""
        echo "Total Channels: $TOTAL"
        echo "Public Channels: $PUBLIC"
        echo "Private Channels: $PRIVATE"
    }
    ;;

# HELP
*)
    echo "Mattermost Channel Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list <team>           List channels in team (default)"
    echo "  list <team> --all     Include archived channels"
    echo "  list <team> --deleted Include deleted channels"
    echo "  public <team>         List public channels only"
    echo "  private <team>        List private channels only"
    echo ""
    echo "LOOKUP:"
    echo "  get <channel>                  Get channel by ID"
    echo "  get-by-name <team> <name>      Get by team and name"
    echo "  search <team> <term>           Search channels"
    echo ""
    echo "CREATION:"
    echo "  create <team> <name> [display] [--private]  Create channel"
    echo "  create-group <team> <name> <users>          Create with members"
    echo ""
    echo "MODIFICATION:"
    echo "  rename <channel> <new_name>        Rename channel"
    echo "  set-header <channel> <header>      Set channel header"
    echo "  set-purpose <channel> <purpose>    Set channel purpose"
    echo "  make-private <channel>             Convert to private"
    echo "  make-public <channel>              Convert to public"
    echo "  move <channel> <new_team>          Move to different team"
    echo ""
    echo "STATUS:"
    echo "  archive <channel>           Archive channel"
    echo "  restore <channel>           Restore archived channel"
    echo "  delete <channel>            Soft delete (archive)"
    echo "  delete <channel> --permanent   Hard delete (no recovery)"
    echo ""
    echo "MEMBERS:"
    echo "  members <channel> [page|--all]    List channel members"
    echo "  add <channel> <user>              Add member"
    echo "  add-many <channel> <u1,u2,...>    Add multiple members"
    echo "  remove <channel> <user>           Remove member"
    echo "  role <channel> <user> admin       Set as channel admin"
    echo ""
    echo "STATISTICS:"
    echo "  stats <channel>      Channel statistics"
    echo "  stats <team>         All channels stats for team"
    ;;
esac
