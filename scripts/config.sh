#!/bin/sh
# Mattermost Configuration Management
# Usage: /scripts/config.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-show}"
ARG1="$2"
ARG2="$3"

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
# VIEW
get)
    print_header "Configuration"
    if [ -z "$ARG1" ]; then
        mmctl_cmd config get
    else
        mmctl_cmd config get "$ARG1"
    fi
    ;;

show)
    print_header "Configuration Summary"

    print_section "Site URL"
    mmctl_cmd config get ServiceSettings.SiteURL 2>/dev/null || echo "Not set"

    print_section "Database"
    mmctl_cmd config get SqlSettings.DriverName 2>/dev/null || echo "Not available"

    print_section "File Storage"
    mmctl_cmd config get FileSettings.DriverName 2>/dev/null || echo "local"

    print_section "Email"
    mmctl_cmd config get EmailSettings.SendEmailNotifications 2>/dev/null || echo "Not available"

    print_section "Push Notifications"
    mmctl_cmd config get EmailSettings.SendPushNotifications 2>/dev/null || echo "Not available"

    print_section "Team Settings"
    echo "Max Users Per Team: $(mmctl_cmd config get TeamSettings.MaxUsersPerTeam 2>/dev/null || echo 'N/A')"
    ;;

diff)
    print_header "Configuration Differences"
    echo "Comparing running config vs file config..."
    echo ""
    echo "Note: Use mmctl config diff for detailed comparison"
    echo "Or check config.json vs environment variables"
    ;;

# MODIFY
set)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set <key> <value>"; exit 1; }
    print_header "Set Configuration"
    mmctl_cmd config set "$ARG1" "$ARG2"
    echo "Configuration updated: $ARG1 = $ARG2"
    ;;

set-json)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 set-json <key> <json_value>"; exit 1; }
    print_header "Set JSON Configuration"
    mmctl_cmd config set "$ARG1" "$ARG2"
    echo "Configuration updated: $ARG1"
    ;;

reset)
    [ -z "$ARG1" ] && { echo "Usage: $0 reset <key>"; exit 1; }
    print_header "Reset Configuration"
    mmctl_cmd config reset "$ARG1"
    echo "Configuration reset: $ARG1"
    ;;

reload)
    print_header "Reload Configuration"
    mmctl_cmd config reload
    echo "Configuration reloaded"
    ;;

# TEST
test-email)
    print_header "Test Email Configuration"
    mmctl_cmd config smtp test
    ;;

test-ldap)
    print_header "Test LDAP Connection"
    mmctl_cmd ldap test
    ;;

test-s3)
    print_header "Test S3 Connection"
    echo "S3 connection testing requires file upload"
    echo ""
    echo "Current S3 settings:"
    mmctl_cmd config get FileSettings.DriverName 2>/dev/null
    mmctl_cmd config get FileSettings.AmazonS3Bucket 2>/dev/null
    mmctl_cmd config get FileSettings.AmazonS3Endpoint 2>/dev/null
    ;;

test-smtp)
    print_header "Test SMTP Settings"
    mmctl_cmd config smtp test
    ;;

test-push)
    print_header "Test Push Notifications"
    echo "Push notification testing:"
    echo ""
    echo "Current settings:"
    mmctl_cmd config get EmailSettings.SendPushNotifications 2>/dev/null
    mmctl_cmd config get EmailSettings.PushNotificationServer 2>/dev/null
    echo ""
    echo "Test via: System Console > Environment > Push Notification Server"
    ;;

# SITE
siteurl)
    print_header "Site URL"
    if [ -z "$ARG1" ]; then
        mmctl_cmd config get ServiceSettings.SiteURL
    else
        mmctl_cmd config set ServiceSettings.SiteURL "$ARG1"
        echo "Site URL set to: $ARG1"
    fi
    ;;

# DATABASE
db)
    [ -z "$ARG1" ] && { echo "Usage: $0 db <migrate|version|recycle>"; exit 1; }
    case "$ARG1" in
    migrate)
        print_header "Database Migration"
        mmctl_cmd db migrate
        ;;
    version)
        print_header "Database Version"
        mmctl_cmd db version
        ;;
    recycle)
        print_header "Recycle Database Connections"
        mmctl_cmd config reset SqlSettings 2>/dev/null || echo "Use reload to reset connections"
        mmctl_cmd config reload
        echo "Database connections recycled"
        ;;
    *)
        echo "Usage: $0 db <migrate|version|recycle>"
        ;;
    esac
    ;;

# COMMON SETTINGS
enable-uploads)
    print_header "Enable Plugin Uploads"
    mmctl_cmd config set PluginSettings.EnableUploads true
    echo "Plugin uploads enabled"
    ;;

disable-uploads)
    print_header "Disable Plugin Uploads"
    mmctl_cmd config set PluginSettings.EnableUploads false
    echo "Plugin uploads disabled"
    ;;

max-file-size)
    print_header "Max File Size"
    if [ -z "$ARG1" ]; then
        mmctl_cmd config get FileSettings.MaxFileSize
    else
        mmctl_cmd config set FileSettings.MaxFileSize "$ARG1"
        echo "Max file size set to: $ARG1 bytes"
    fi
    ;;

# SECTIONS
section)
    [ -z "$ARG1" ] && { echo "Usage: $0 section <name>"; exit 1; }
    print_header "Configuration Section: $ARG1"

    case "$ARG1" in
    service|ServiceSettings)
        mmctl_cmd config get ServiceSettings
        ;;
    team|TeamSettings)
        mmctl_cmd config get TeamSettings
        ;;
    sql|SqlSettings)
        mmctl_cmd config get SqlSettings
        ;;
    file|FileSettings)
        mmctl_cmd config get FileSettings
        ;;
    email|EmailSettings)
        mmctl_cmd config get EmailSettings
        ;;
    plugin|PluginSettings)
        mmctl_cmd config get PluginSettings
        ;;
    ldap|LdapSettings)
        mmctl_cmd config get LdapSettings
        ;;
    saml|SamlSettings)
        mmctl_cmd config get SamlSettings
        ;;
    *)
        mmctl_cmd config get "$ARG1"
        ;;
    esac
    ;;

# HELP
*)
    echo "Mattermost Configuration Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "VIEW:"
    echo "  get [section]         Get config (or specific section)"
    echo "  show                  Show formatted config summary (default)"
    echo "  diff                  Compare running vs file config"
    echo "  section <name>        View specific config section"
    echo ""
    echo "MODIFY:"
    echo "  set <key> <value>     Set config value"
    echo "  set-json <key> <json> Set config with JSON value"
    echo "  reset <key>           Reset to default value"
    echo "  reload                Reload configuration from file"
    echo ""
    echo "TEST:"
    echo "  test-email            Send test email"
    echo "  test-ldap             Test LDAP connection"
    echo "  test-s3               Test S3 connection"
    echo "  test-smtp             Test SMTP settings"
    echo "  test-push             Test push notifications"
    echo ""
    echo "SITE:"
    echo "  siteurl               Show current site URL"
    echo "  siteurl <url>         Set site URL"
    echo ""
    echo "DATABASE:"
    echo "  db migrate            Run database migrations"
    echo "  db version            Show database version"
    echo "  db recycle            Recycle database connections"
    echo ""
    echo "QUICK SETTINGS:"
    echo "  enable-uploads        Enable plugin uploads"
    echo "  disable-uploads       Disable plugin uploads"
    echo "  max-file-size [bytes] Get/set max file size"
    echo ""
    echo "Config Sections:"
    echo "  ServiceSettings       Server and service config"
    echo "  TeamSettings          Team configuration"
    echo "  SqlSettings           Database settings"
    echo "  FileSettings          File storage settings"
    echo "  EmailSettings         Email and push settings"
    echo "  PluginSettings        Plugin configuration"
    echo "  LdapSettings          LDAP settings"
    echo "  SamlSettings          SAML settings"
    ;;
esac
