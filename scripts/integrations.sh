#!/bin/sh
# Mattermost Integrations Management
# Usage: /scripts/integrations.sh [command] [args]
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
# LDAP
ldap)
    [ -z "$ARG1" ] && { echo "Usage: $0 ldap <status|test|sync|users>"; exit 1; }
    case "$ARG1" in
    status)
        print_header "LDAP Status"
        echo "LDAP Configuration:"
        mmctl_cmd config get LdapSettings.Enable 2>/dev/null || echo "LDAP not configured"
        mmctl_cmd config get LdapSettings.LdapServer 2>/dev/null
        mmctl_cmd config get LdapSettings.BaseDN 2>/dev/null
        ;;
    test)
        print_header "Test LDAP Connection"
        mmctl_cmd ldap test
        ;;
    sync)
        print_header "LDAP Sync"
        mmctl_cmd ldap sync
        echo "LDAP sync triggered"
        ;;
    users)
        print_header "LDAP-Synced Users"
        # List users with LDAP auth
        mmctl_json user list --all | grep -B10 '"auth_service":"ldap"' | grep '"username"' | cut -d'"' -f4 || echo "No LDAP users found"
        ;;
    job|jobs)
        print_header "LDAP Sync Jobs"
        mmctl_cmd job list --type ldap_sync
        ;;
    *)
        echo "Usage: $0 ldap <status|test|sync|users|jobs>"
        ;;
    esac
    ;;

# SAML
saml)
    [ -z "$ARG1" ] && { echo "Usage: $0 saml <status|metadata>"; exit 1; }
    case "$ARG1" in
    status)
        print_header "SAML Status"
        echo "SAML Configuration:"
        mmctl_cmd config get SamlSettings.Enable 2>/dev/null || echo "SAML not configured"
        mmctl_cmd config get SamlSettings.IdpUrl 2>/dev/null
        ;;
    metadata)
        print_header "SAML Metadata"
        echo "Service Provider Metadata:"
        echo ""
        SITEURL=$(mmctl_cmd config get ServiceSettings.SiteURL 2>/dev/null | tr -d '"')
        echo "Entity ID: $SITEURL/login/sso/saml"
        echo "ACS URL: $SITEURL/login/sso/saml"
        echo ""
        echo "Full metadata available at:"
        echo "$SITEURL/api/v4/saml/metadata"
        ;;
    *)
        echo "Usage: $0 saml <status|metadata>"
        ;;
    esac
    ;;

# OAUTH
oauth)
    [ -z "$ARG1" ] && { echo "Usage: $0 oauth <list|get|create|delete>"; exit 1; }
    case "$ARG1" in
    list)
        print_header "OAuth Apps"
        mmctl_cmd oauth list 2>/dev/null || echo "No OAuth apps configured"
        ;;
    get)
        [ -z "$ARG2" ] && { echo "Usage: $0 oauth get <app_id>"; exit 1; }
        print_header "OAuth App Details"
        mmctl_cmd oauth get "$ARG2" 2>/dev/null || echo "App not found"
        ;;
    create)
        print_header "Create OAuth App"
        echo "OAuth app creation requires admin console or API"
        echo ""
        echo "Required fields:"
        echo "  - Name"
        echo "  - Description"
        echo "  - Homepage URL"
        echo "  - Callback URLs"
        echo ""
        echo "Use System Console > Integrations > OAuth 2.0 Applications"
        ;;
    delete)
        [ -z "$ARG2" ] && { echo "Usage: $0 oauth delete <app_id>"; exit 1; }
        print_header "Delete OAuth App"
        mmctl_cmd oauth delete "$ARG2"
        echo "OAuth app deleted"
        ;;
    *)
        echo "Usage: $0 oauth <list|get|create|delete>"
        ;;
    esac
    ;;

# GITLAB/AUTHENTIK SSO
gitlab)
    print_header "GitLab/OAuth SSO Status"
    echo "GitLab OAuth Settings (also used for Authentik):"
    mmctl_cmd config get GitLabSettings.Enable 2>/dev/null
    mmctl_cmd config get GitLabSettings.AuthEndpoint 2>/dev/null
    mmctl_cmd config get GitLabSettings.TokenEndpoint 2>/dev/null
    mmctl_cmd config get GitLabSettings.UserApiEndpoint 2>/dev/null
    ;;

# SLASH COMMANDS
slash)
    [ -z "$ARG1" ] && { echo "Usage: $0 slash <list|create|delete|test>"; exit 1; }
    case "$ARG1" in
    list)
        print_header "Slash Commands"
        if [ -z "$ARG2" ]; then
            mmctl_cmd command list --all 2>/dev/null || echo "No slash commands"
        else
            mmctl_cmd command list "$ARG2"
        fi
        ;;
    create)
        [ -z "$ARG2" ] || [ -z "$ARG3" ] || [ -z "$ARG4" ] && { echo "Usage: $0 slash create <team> <trigger> <url>"; exit 1; }
        print_header "Create Slash Command"
        mmctl_cmd command create "$ARG2" --trigger-word "$ARG3" --url "$ARG4" --method POST
        echo "Slash command created"
        ;;
    delete)
        [ -z "$ARG2" ] && { echo "Usage: $0 slash delete <command_id>"; exit 1; }
        print_header "Delete Slash Command"
        mmctl_cmd command delete "$ARG2"
        echo "Slash command deleted"
        ;;
    test)
        [ -z "$ARG2" ] && { echo "Usage: $0 slash test <command_id>"; exit 1; }
        print_header "Test Slash Command"
        echo "Slash command testing requires usage in Mattermost client"
        echo "Command ID: $ARG2"
        ;;
    *)
        echo "Usage: $0 slash <list|create|delete|test>"
        ;;
    esac
    ;;

# EMAIL
email)
    [ -z "$ARG1" ] && { echo "Usage: $0 email <status|test>"; exit 1; }
    case "$ARG1" in
    status)
        print_header "Email Configuration"
        echo "Email Settings:"
        mmctl_cmd config get EmailSettings.SendEmailNotifications 2>/dev/null
        mmctl_cmd config get EmailSettings.SMTPServer 2>/dev/null
        mmctl_cmd config get EmailSettings.SMTPPort 2>/dev/null
        mmctl_cmd config get EmailSettings.FeedbackEmail 2>/dev/null
        ;;
    test)
        print_header "Test Email"
        mmctl_cmd config smtp test
        ;;
    *)
        echo "Usage: $0 email <status|test>"
        ;;
    esac
    ;;

# PUSH NOTIFICATIONS
push)
    [ -z "$ARG1" ] && { echo "Usage: $0 push <status>"; exit 1; }
    case "$ARG1" in
    status)
        print_header "Push Notification Status"
        echo "Push Settings:"
        mmctl_cmd config get EmailSettings.SendPushNotifications 2>/dev/null
        mmctl_cmd config get EmailSettings.PushNotificationServer 2>/dev/null
        ;;
    *)
        echo "Usage: $0 push <status>"
        ;;
    esac
    ;;

# STATUS SUMMARY
status)
    print_header "Integration Status Summary"

    print_section "LDAP"
    LDAP_ENABLED=$(mmctl_cmd config get LdapSettings.Enable 2>/dev/null | tr -d '"')
    echo "Enabled: ${LDAP_ENABLED:-false}"

    print_section "SAML"
    SAML_ENABLED=$(mmctl_cmd config get SamlSettings.Enable 2>/dev/null | tr -d '"')
    echo "Enabled: ${SAML_ENABLED:-false}"

    print_section "GitLab OAuth"
    GITLAB_ENABLED=$(mmctl_cmd config get GitLabSettings.Enable 2>/dev/null | tr -d '"')
    echo "Enabled: ${GITLAB_ENABLED:-false}"

    print_section "Email"
    EMAIL_ENABLED=$(mmctl_cmd config get EmailSettings.SendEmailNotifications 2>/dev/null | tr -d '"')
    echo "Notifications: ${EMAIL_ENABLED:-false}"

    print_section "Push Notifications"
    PUSH_ENABLED=$(mmctl_cmd config get EmailSettings.SendPushNotifications 2>/dev/null | tr -d '"')
    echo "Enabled: ${PUSH_ENABLED:-false}"
    ;;

# HELP
*)
    echo "Mattermost Integrations Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "STATUS:"
    echo "  status                Integration status summary"
    echo ""
    echo "LDAP:"
    echo "  ldap status           LDAP connection status"
    echo "  ldap test             Test LDAP connection"
    echo "  ldap sync             Trigger LDAP sync"
    echo "  ldap users            List LDAP-synced users"
    echo "  ldap jobs             List LDAP sync jobs"
    echo ""
    echo "SAML:"
    echo "  saml status           SAML status"
    echo "  saml metadata         Show SAML metadata"
    echo ""
    echo "OAUTH:"
    echo "  oauth list            List OAuth apps"
    echo "  oauth get <id>        Get OAuth app details"
    echo "  oauth create          Create OAuth app (via console)"
    echo "  oauth delete <id>     Delete OAuth app"
    echo ""
    echo "GITLAB/SSO:"
    echo "  gitlab                GitLab OAuth status (Authentik)"
    echo ""
    echo "SLASH COMMANDS:"
    echo "  slash list [team]     List slash commands"
    echo "  slash create <team> <trigger> <url>"
    echo "                        Create slash command"
    echo "  slash delete <id>     Delete slash command"
    echo "  slash test <id>       Test slash command"
    echo ""
    echo "EMAIL:"
    echo "  email status          Email configuration status"
    echo "  email test            Send test email"
    echo ""
    echo "PUSH:"
    echo "  push status           Push notification status"
    ;;
esac
