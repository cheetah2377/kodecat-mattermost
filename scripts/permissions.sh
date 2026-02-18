#!/bin/sh
# Mattermost Permission Management
# Usage: /scripts/permissions.sh [command] [args]
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
# ROLES
list)
    print_header "Mattermost Roles"
    mmctl_cmd permissions role show system_admin
    mmctl_cmd permissions role show system_user
    mmctl_cmd permissions role show team_admin
    mmctl_cmd permissions role show team_user
    mmctl_cmd permissions role show channel_admin
    mmctl_cmd permissions role show channel_user
    ;;

get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <role_name>"; exit 1; }
    print_header "Role Details: $ARG1"
    mmctl_cmd permissions role show "$ARG1"
    ;;

system-roles)
    print_header "System Roles"

    print_section "System Admin"
    mmctl_cmd permissions role show system_admin

    print_section "System User"
    mmctl_cmd permissions role show system_user

    print_section "System Guest"
    mmctl_cmd permissions role show system_guest
    ;;

custom-roles)
    print_header "Custom Roles"
    echo "Custom roles are managed through permission schemes"
    echo ""
    echo "Use: $0 schemes to list permission schemes"
    ;;

# SCHEMES
schemes)
    print_header "Permission Schemes"
    mmctl_cmd permissions role show system_scheme_admin 2>/dev/null || echo "No custom schemes found"
    ;;

scheme)
    [ -z "$ARG1" ] && { echo "Usage: $0 scheme <scheme_id>"; exit 1; }
    print_header "Scheme Details"
    echo "Scheme: $ARG1"
    echo ""
    echo "Use mmctl API or admin console for detailed scheme info"
    ;;

scheme-teams)
    [ -z "$ARG1" ] && { echo "Usage: $0 scheme-teams <scheme_id>"; exit 1; }
    print_header "Teams Using Scheme"
    echo "Scheme: $ARG1"
    echo ""
    echo "Check admin console for teams using this scheme"
    ;;

scheme-channels)
    [ -z "$ARG1" ] && { echo "Usage: $0 scheme-channels <scheme_id>"; exit 1; }
    print_header "Channels Using Scheme"
    echo "Scheme: $ARG1"
    echo ""
    echo "Check admin console for channels using this scheme"
    ;;

# MANAGEMENT
add)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 add <role> <permission>"; exit 1; }
    print_header "Add Permission to Role"
    mmctl_cmd permissions add "$ARG1" "$ARG2"
    echo "Permission $ARG2 added to role $ARG1"
    ;;

remove)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 remove <role> <permission>"; exit 1; }
    print_header "Remove Permission from Role"
    mmctl_cmd permissions remove "$ARG1" "$ARG2"
    echo "Permission $ARG2 removed from role $ARG1"
    ;;

assign)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 assign <user> <role>"; exit 1; }
    print_header "Assign Role to User"
    mmctl_cmd user change-roles "$ARG1" "$ARG2"
    echo "Role $ARG2 assigned to $ARG1"
    ;;

unassign)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 unassign <user> <role>"; exit 1; }
    print_header "Remove Role from User"
    echo "Use: $0 assign <user> <new_roles> to replace roles"
    echo "Roles cannot be individually unassigned via CLI"
    ;;

# RESET
reset-all)
    print_header "Reset All Permissions"
    echo "WARNING: This will reset all permissions to defaults"
    echo ""
    echo "Use the admin console to reset permissions"
    echo "Or reconfigure via mmctl permissions commands"
    ;;

# COMMON PERMISSIONS
permissions-list)
    print_header "Common Permissions"
    echo ""
    echo "System Permissions:"
    echo "  - sysconsole_read_*          Read system console"
    echo "  - sysconsole_write_*         Write system console"
    echo "  - manage_system              Manage system settings"
    echo ""
    echo "Team Permissions:"
    echo "  - create_team                Create teams"
    echo "  - manage_team                Manage team settings"
    echo "  - invite_user                Invite users to team"
    echo "  - add_user_to_team           Add users to team"
    echo "  - remove_user_from_team      Remove users from team"
    echo ""
    echo "Channel Permissions:"
    echo "  - create_public_channel      Create public channels"
    echo "  - create_private_channel     Create private channels"
    echo "  - manage_public_channel_properties   Edit public channels"
    echo "  - manage_private_channel_properties  Edit private channels"
    echo "  - delete_public_channel      Delete public channels"
    echo "  - delete_private_channel     Delete private channels"
    echo ""
    echo "Post Permissions:"
    echo "  - create_post                Create posts"
    echo "  - edit_post                  Edit own posts"
    echo "  - edit_others_posts          Edit others posts"
    echo "  - delete_post                Delete own posts"
    echo "  - delete_others_posts        Delete others posts"
    echo ""
    echo "User Permissions:"
    echo "  - manage_others_webhooks     Manage webhooks"
    echo "  - manage_slash_commands      Manage slash commands"
    echo "  - manage_others_slash_commands   Manage others commands"
    ;;

# HELP
*)
    echo "Mattermost Permission Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "ROLES:"
    echo "  list                  List all roles (default)"
    echo "  get <role>            Get role details"
    echo "  system-roles          List system roles only"
    echo "  custom-roles          List custom roles only"
    echo ""
    echo "SCHEMES:"
    echo "  schemes               List permission schemes"
    echo "  scheme <id>           Get scheme details"
    echo "  scheme-teams <id>     Teams using scheme"
    echo "  scheme-channels <id>  Channels using scheme"
    echo ""
    echo "MANAGEMENT:"
    echo "  add <role> <perm>     Add permission to role"
    echo "  remove <role> <perm>  Remove permission from role"
    echo "  assign <user> <role>  Assign role to user"
    echo "  unassign <user> <role>  Remove role from user"
    echo ""
    echo "RESET:"
    echo "  reset-all             Reset all permissions to defaults"
    echo ""
    echo "REFERENCE:"
    echo "  permissions-list      List common permissions"
    echo ""
    echo "Common Roles:"
    echo "  - system_admin        Full system access"
    echo "  - system_user         Standard user"
    echo "  - system_guest        Guest user"
    echo "  - team_admin          Team administrator"
    echo "  - team_user           Team member"
    echo "  - channel_admin       Channel administrator"
    echo "  - channel_user        Channel member"
    ;;
esac
