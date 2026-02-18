#!/bin/sh
# Mattermost Post Management
# Usage: /scripts/posts.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-help}"
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
# LOOKUP
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <post_id>"; exit 1; }
    print_header "Post Details"
    mmctl_cmd post get "$ARG1"
    ;;

thread)
    [ -z "$ARG1" ] && { echo "Usage: $0 thread <post_id>"; exit 1; }
    print_header "Post Thread"
    mmctl_cmd post get "$ARG1" --thread
    ;;

# SEARCH
search)
    [ -z "$ARG1" ] && { echo "Usage: $0 search <term> [team]"; exit 1; }
    print_header "Search Results: $ARG1"
    if [ -n "$ARG2" ]; then
        mmctl_cmd post search "$ARG1" --team "$ARG2"
    else
        mmctl_cmd post search "$ARG1"
    fi
    ;;

from-user)
    [ -z "$ARG1" ] && { echo "Usage: $0 from-user <user>"; exit 1; }
    print_header "Posts from User: $ARG1"
    mmctl_cmd post search "from:$ARG1"
    ;;

in-channel)
    [ -z "$ARG1" ] && { echo "Usage: $0 in-channel <channel> [term]"; exit 1; }
    print_header "Posts in Channel: $ARG1"
    if [ -n "$ARG2" ]; then
        mmctl_cmd post search "in:$ARG1 $ARG2"
    else
        mmctl_cmd post search "in:$ARG1"
    fi
    ;;

# CREATION
send)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 send <channel> <message>"; exit 1; }
    print_header "Send Message"
    mmctl_cmd post create "$ARG1" --message "$ARG2"
    echo "Message sent to $ARG1"
    ;;

reply)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 reply <post_id> <message>"; exit 1; }
    print_header "Reply to Post"
    mmctl_cmd post create --reply "$ARG1" --message "$ARG2"
    echo "Reply sent"
    ;;

# MODIFICATION
delete)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete <post_id>"; exit 1; }
    print_header "Delete Post"
    mmctl_cmd post delete "$ARG1"
    echo "Post $ARG1 deleted"
    ;;

# PIN/UNPIN
pin)
    [ -z "$ARG1" ] && { echo "Usage: $0 pin <post_id>"; exit 1; }
    print_header "Pin Post"
    echo "Pinning is handled via API or UI"
    echo "Post ID: $ARG1"
    ;;

unpin)
    [ -z "$ARG1" ] && { echo "Usage: $0 unpin <post_id>"; exit 1; }
    print_header "Unpin Post"
    echo "Unpinning is handled via API or UI"
    echo "Post ID: $ARG1"
    ;;

# FLAGS
flag)
    [ -z "$ARG1" ] && { echo "Usage: $0 flag <post_id>"; exit 1; }
    print_header "Flag Post"
    echo "Flagging is user-specific and handled via UI"
    echo "Post ID: $ARG1"
    ;;

unflag)
    [ -z "$ARG1" ] && { echo "Usage: $0 unflag <post_id>"; exit 1; }
    print_header "Unflag Post"
    echo "Unflagging is user-specific and handled via UI"
    echo "Post ID: $ARG1"
    ;;

flagged)
    print_header "Flagged Posts"
    echo "Flagged posts are user-specific"
    echo "View flagged posts in the UI"
    ;;

# REACTIONS
react)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 react <post_id> <emoji>"; exit 1; }
    print_header "Add Reaction"
    echo "Reactions are handled via API or UI"
    echo "Post: $ARG1, Emoji: $ARG2"
    ;;

reactions)
    [ -z "$ARG1" ] && { echo "Usage: $0 reactions <post_id>"; exit 1; }
    print_header "Post Reactions"
    mmctl_cmd post get "$ARG1" | grep -i reaction || echo "No reactions or not supported via CLI"
    ;;

# CLEANUP
cleanup)
    [ -z "$ARG1" ] && { echo "Usage: $0 cleanup <days> [channel]"; exit 1; }
    print_header "Cleanup Old Posts"

    DAYS="$ARG1"
    CHANNEL="$ARG2"

    echo "This operation requires data retention policy configuration"
    echo ""
    echo "To clean up posts older than $DAYS days:"
    echo "1. Enable data retention in System Console"
    echo "2. Configure message retention period"
    echo "3. Run data retention job"
    echo ""
    echo "Or use: /scripts/jobs.sh to check data retention jobs"
    ;;

# EXPORT
export)
    [ -z "$ARG1" ] && { echo "Usage: $0 export <channel> [since_date]"; exit 1; }
    print_header "Export Channel Posts"
    echo "Use /scripts/import-export.sh for bulk exports"
    echo "Channel: $ARG1"
    ;;

# HELP
*)
    echo "Mattermost Post Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LOOKUP:"
    echo "  get <post_id>         Get post details"
    echo "  thread <post_id>      Get post thread"
    echo ""
    echo "SEARCH:"
    echo "  search <term> [team]  Search posts globally or in team"
    echo "  from-user <user>      Posts from specific user"
    echo "  in-channel <ch> [term]  Search in specific channel"
    echo ""
    echo "CREATION:"
    echo "  send <channel> <message>      Send message to channel"
    echo "  reply <post_id> <message>     Reply to post"
    echo ""
    echo "MODIFICATION:"
    echo "  delete <post_id>      Delete post"
    echo ""
    echo "PIN/UNPIN:"
    echo "  pin <post_id>         Pin post to channel"
    echo "  unpin <post_id>       Unpin post"
    echo ""
    echo "REACTIONS:"
    echo "  react <post_id> <emoji>   Add reaction"
    echo "  reactions <post_id>       List reactions on post"
    echo ""
    echo "FLAGS:"
    echo "  flag <post_id>        Flag post for follow-up"
    echo "  unflag <post_id>      Remove flag"
    echo "  flagged               List all flagged posts"
    echo ""
    echo "CLEANUP:"
    echo "  cleanup <days> [channel]  Delete posts older than N days"
    echo ""
    echo "EXPORT:"
    echo "  export <channel>      Export channel posts"
    echo ""
    echo "Search Operators:"
    echo "  from:<user>           Posts from user"
    echo "  in:<channel>          Posts in channel"
    echo "  on:<date>             Posts on date"
    echo "  before:<date>         Posts before date"
    echo "  after:<date>          Posts after date"
    ;;
esac
