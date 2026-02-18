#!/bin/sh
# Mattermost User Management
# Usage: /scripts/users.sh [command] [args]
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

# Generate random password
gen_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%' | fold -w 16 | head -n 1
}

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
    print_header "Mattermost Users"
    if [ "$ARG1" = "--all" ]; then
        mmctl_cmd user list --all
    elif [ "$ARG1" = "--json" ]; then
        mmctl_json user list --all
    else
        PAGE="${ARG1:-0}"
        mmctl_cmd user list --page "$PAGE" --per-page 50
    fi
    ;;

active)
    print_header "Active Users"
    mmctl_cmd user list --all | grep -v "(deactivated)" || echo "No active users found"
    ;;

inactive)
    print_header "Inactive Users"
    mmctl_cmd user list --all | grep "(deactivated)" || echo "No inactive users found"
    ;;

admins)
    print_header "System Administrators"
    # List users with system admin role
    mmctl_json user list --all 2>/dev/null | grep -B5 '"system_admin"' | grep '"username"' | cut -d'"' -f4 || echo "No admins found"
    ;;

guests)
    print_header "Guest Users"
    mmctl_json user list --all 2>/dev/null | grep -B5 '"system_guest"' | grep '"username"' | cut -d'"' -f4 || echo "No guests found"
    ;;

recently-active)
    print_header "Recently Active Users (Last 24h)"
    # Note: This requires status tracking
    echo "Use mmctl to check user status or check analytics"
    mmctl_cmd user list --page 0 --per-page 20
    ;;

stats)
    print_header "User Statistics"
    TOTAL=$(mmctl_json user list --all 2>/dev/null | grep -c '"id":' || echo "0")
    ACTIVE=$(mmctl_json user list --all 2>/dev/null | grep -v '"delete_at":[1-9]' | grep -c '"id":' || echo "0")
    INACTIVE=$((TOTAL - ACTIVE))

    echo ""
    echo "Total Users: $TOTAL"
    echo "Active Users: $ACTIVE"
    echo "Deactivated Users: $INACTIVE"
    ;;

# LOOKUP
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <user_id|email|username>"; exit 1; }
    print_header "User Details"
    mmctl_cmd user get "$ARG1" || { echo "User not found: $ARG1"; exit 1; }
    ;;

search)
    [ -z "$ARG1" ] && { echo "Usage: $0 search <term>"; exit 1; }
    print_header "Search Results: $ARG1"
    mmctl_cmd user search "$ARG1"
    ;;

# CREATION
create)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 create <email> <username> [password]"; exit 1; }
    EMAIL="$ARG1"
    USERNAME="$ARG2"
    PASSWORD="${ARG3:-$(gen_password)}"

    print_header "Create User"
    echo "Email: $EMAIL"
    echo "Username: $USERNAME"

    mmctl_cmd user create --email "$EMAIL" --username "$USERNAME" --password "$PASSWORD"

    echo ""
    echo "User created successfully!"
    if [ -z "$ARG3" ]; then
        echo "Generated password: $PASSWORD"
    fi
    ;;

create-admin)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 create-admin <email> <username> [password]"; exit 1; }
    EMAIL="$ARG1"
    USERNAME="$ARG2"
    PASSWORD="${ARG3:-$(gen_password)}"

    print_header "Create Admin User"
    echo "Email: $EMAIL"
    echo "Username: $USERNAME"

    mmctl_cmd user create --email "$EMAIL" --username "$USERNAME" --password "$PASSWORD" --system-admin

    echo ""
    echo "Admin user created successfully!"
    if [ -z "$ARG3" ]; then
        echo "Generated password: $PASSWORD"
    fi
    ;;

invite)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 invite <email> <team>"; exit 1; }
    print_header "Send Invitation"
    mmctl_cmd user invite "$ARG1" "$ARG2"
    echo "Invitation sent to $ARG1 for team $ARG2"
    ;;

# STATUS
activate)
    [ -z "$ARG1" ] && { echo "Usage: $0 activate <user>"; exit 1; }
    print_header "Activate User"
    mmctl_cmd user activate "$ARG1"
    echo "User $ARG1 activated"
    ;;

deactivate)
    [ -z "$ARG1" ] && { echo "Usage: $0 deactivate <user>"; exit 1; }
    print_header "Deactivate User"
    mmctl_cmd user deactivate "$ARG1"
    echo "User $ARG1 deactivated"
    ;;

delete)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete <user>"; exit 1; }
    print_header "Delete User (Permanent)"
    echo "WARNING: This will permanently delete user $ARG1"
    echo "This action cannot be undone!"
    echo ""
    echo "Proceeding with deletion..."
    mmctl_cmd user delete "$ARG1" --confirm
    echo "User $ARG1 deleted"
    ;;

# AUTHENTICATION
reset-pwd|reset-password)
    [ -z "$ARG1" ] && { echo "Usage: $0 reset-pwd <user> [new_password]"; exit 1; }
    PASSWORD="${ARG2:-$(gen_password)}"

    print_header "Reset Password"
    mmctl_cmd user reset-password "$ARG1" --password "$PASSWORD"

    echo "Password reset for $ARG1"
    if [ -z "$ARG2" ]; then
        echo "New password: $PASSWORD"
    fi
    ;;

mfa)
    [ -z "$ARG1" ] && { echo "Usage: $0 mfa <status|disable> <user>"; exit 1; }
    case "$ARG1" in
    status)
        [ -z "$ARG2" ] && { echo "Usage: $0 mfa status <user>"; exit 1; }
        print_header "MFA Status"
        mmctl_cmd user get "$ARG2" | grep -i mfa || echo "MFA status not available"
        ;;
    disable)
        [ -z "$ARG2" ] && { echo "Usage: $0 mfa disable <user>"; exit 1; }
        print_header "Disable MFA"
        mmctl_cmd user resetmfa "$ARG2"
        echo "MFA disabled for $ARG2"
        ;;
    *)
        echo "Usage: $0 mfa <status|disable> <user>"
        ;;
    esac
    ;;

send-pwd-reset)
    [ -z "$ARG1" ] && { echo "Usage: $0 send-pwd-reset <user>"; exit 1; }
    print_header "Send Password Reset Email"
    # Note: This requires email to be configured
    echo "Feature requires email configuration"
    echo "Use reset-pwd to set password directly"
    ;;

verify-email)
    [ -z "$ARG1" ] && { echo "Usage: $0 verify-email <user>"; exit 1; }
    print_header "Verify Email"
    mmctl_cmd user verify "$ARG1"
    echo "Email verified for $ARG1"
    ;;

# ROLES
promote)
    [ -z "$ARG1" ] && { echo "Usage: $0 promote <user>"; exit 1; }
    print_header "Promote to System Admin"
    mmctl_cmd roles system-admin "$ARG1"
    echo "User $ARG1 promoted to system admin"
    ;;

demote)
    [ -z "$ARG1" ] && { echo "Usage: $0 demote <user>"; exit 1; }
    print_header "Remove Admin Role"
    mmctl_cmd roles member "$ARG1"
    echo "User $ARG1 demoted to member"
    ;;

set-role)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-role <user> <roles>"; exit 1; }
    print_header "Set User Roles"
    mmctl_cmd user change-roles "$ARG1" "$ARG2"
    echo "Roles set for $ARG1: $ARG2"
    ;;

make-guest)
    [ -z "$ARG1" ] && { echo "Usage: $0 make-guest <user>"; exit 1; }
    print_header "Convert to Guest"
    mmctl_cmd user convert "$ARG1" --guest
    echo "User $ARG1 converted to guest"
    ;;

# SESSIONS
sessions)
    [ -z "$ARG1" ] && { echo "Usage: $0 sessions <user>"; exit 1; }
    print_header "Active Sessions"
    mmctl_cmd user session "$ARG1"
    ;;

logout)
    [ -z "$ARG1" ] && { echo "Usage: $0 logout <user>"; exit 1; }
    print_header "Revoke All Sessions"
    mmctl_cmd user logout "$ARG1"
    echo "All sessions revoked for $ARG1"
    ;;

logout-all)
    print_header "Revoke All User Sessions"
    echo "This will log out ALL users from ALL sessions"
    mmctl_cmd user logout --all
    echo "All user sessions revoked"
    ;;

# TOKENS
tokens)
    [ -z "$ARG1" ] && { echo "Usage: $0 tokens <list|create|revoke> <user> [args]"; exit 1; }
    case "$ARG1" in
    list)
        [ -z "$ARG2" ] && { echo "Usage: $0 tokens list <user>"; exit 1; }
        print_header "Personal Access Tokens"
        mmctl_cmd token list "$ARG2"
        ;;
    create)
        [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 tokens create <user> <description>"; exit 1; }
        print_header "Create Token"
        mmctl_cmd token generate "$ARG2" "$ARG3"
        ;;
    revoke)
        [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 tokens revoke <user> <token_id>"; exit 1; }
        print_header "Revoke Token"
        mmctl_cmd token revoke "$ARG3"
        echo "Token revoked"
        ;;
    *)
        echo "Usage: $0 tokens <list|create|revoke> <user> [args]"
        ;;
    esac
    ;;

# PREFERENCES
prefs|preferences)
    [ -z "$ARG1" ] && { echo "Usage: $0 prefs <user>"; exit 1; }
    print_header "User Preferences"
    mmctl_cmd user preferences get "$ARG1" 2>/dev/null || echo "Preferences not available via CLI"
    ;;

# HELP
*)
    echo "Mattermost User Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list [page|--all]     List users (paginated or all)"
    echo "  active                List active users only"
    echo "  inactive              List deactivated users"
    echo "  admins                List system admins"
    echo "  guests                List guest users"
    echo "  recently-active       Users active in last 24h"
    echo "  stats                 User statistics"
    echo ""
    echo "LOOKUP:"
    echo "  get <user>            Get user by ID/email/username"
    echo "  search <term>         Search users"
    echo ""
    echo "CREATION:"
    echo "  create <email> <username> [password]    Create user"
    echo "  create-admin <email> <username>         Create admin"
    echo "  invite <email> <team>                   Send invitation"
    echo ""
    echo "STATUS:"
    echo "  activate <user>       Activate deactivated user"
    echo "  deactivate <user>     Deactivate user (soft delete)"
    echo "  delete <user>         Permanently delete"
    echo ""
    echo "AUTHENTICATION:"
    echo "  reset-pwd <user> [password]   Reset password"
    echo "  mfa status <user>             Check MFA status"
    echo "  mfa disable <user>            Disable MFA"
    echo "  verify-email <user>           Force verify email"
    echo ""
    echo "ROLES:"
    echo "  promote <user>        Make system admin"
    echo "  demote <user>         Remove admin role"
    echo "  set-role <user> <roles>   Set custom roles"
    echo "  make-guest <user>     Convert to guest"
    echo ""
    echo "SESSIONS:"
    echo "  sessions <user>       List active sessions"
    echo "  logout <user>         Revoke all sessions"
    echo "  logout-all            Revoke all user sessions"
    echo ""
    echo "TOKENS:"
    echo "  tokens list <user>              List tokens"
    echo "  tokens create <user> <desc>     Create token"
    echo "  tokens revoke <user> <id>       Revoke token"
    echo ""
    echo "PREFERENCES:"
    echo "  prefs <user>          Show user preferences"
    ;;
esac
