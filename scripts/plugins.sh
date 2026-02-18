#!/bin/sh
# Mattermost Plugin Management
# Usage: /scripts/plugins.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-list}"
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
# LISTING
list)
    print_header "Installed Plugins"
    if [ "$ARG1" = "--json" ]; then
        mmctl_json plugin list
    else
        mmctl_cmd plugin list
    fi
    ;;

installed)
    print_header "Installed Plugins"
    mmctl_cmd plugin list
    ;;

active)
    print_header "Active Plugins"
    mmctl_json plugin list 2>/dev/null | grep -B5 '"state":2' | grep '"id"' | cut -d'"' -f4 || echo "No active plugins"
    ;;

inactive)
    print_header "Inactive Plugins"
    mmctl_json plugin list 2>/dev/null | grep -B5 '"state":0' | grep '"id"' | cut -d'"' -f4 || echo "No inactive plugins"
    ;;

marketplace)
    print_header "Marketplace Plugins"
    mmctl_cmd plugin marketplace list 2>/dev/null || echo "Marketplace not accessible"
    ;;

# MANAGEMENT
install)
    [ -z "$ARG1" ] && { echo "Usage: $0 install <plugin_id|file_path>"; exit 1; }
    print_header "Install Plugin"

    if [ -f "$ARG1" ]; then
        # Install from file
        echo "Installing from file: $ARG1"
        mmctl_cmd plugin add "$ARG1"
    else
        # Install from marketplace
        echo "Installing from marketplace: $ARG1"
        mmctl_cmd plugin marketplace install "$ARG1"
    fi
    echo ""
    echo "Plugin installed successfully"
    echo "Enable with: $0 enable $ARG1"
    ;;

enable)
    [ -z "$ARG1" ] && { echo "Usage: $0 enable <plugin_id>"; exit 1; }
    print_header "Enable Plugin"
    mmctl_cmd plugin enable "$ARG1"
    echo "Plugin $ARG1 enabled"
    ;;

disable)
    [ -z "$ARG1" ] && { echo "Usage: $0 disable <plugin_id>"; exit 1; }
    print_header "Disable Plugin"
    mmctl_cmd plugin disable "$ARG1"
    echo "Plugin $ARG1 disabled"
    ;;

remove)
    [ -z "$ARG1" ] && { echo "Usage: $0 remove <plugin_id>"; exit 1; }
    print_header "Remove Plugin"
    # Disable first
    mmctl_cmd plugin disable "$ARG1" 2>/dev/null || true
    # Then remove
    mmctl_cmd plugin delete "$ARG1"
    echo "Plugin $ARG1 removed"
    ;;

update)
    [ -z "$ARG1" ] && { echo "Usage: $0 update <plugin_id>"; exit 1; }
    print_header "Update Plugin"
    echo "Updating $ARG1 from marketplace..."

    # Disable, remove, reinstall
    mmctl_cmd plugin disable "$ARG1" 2>/dev/null || true
    mmctl_cmd plugin delete "$ARG1" 2>/dev/null || true
    mmctl_cmd plugin marketplace install "$ARG1"
    mmctl_cmd plugin enable "$ARG1"

    echo "Plugin $ARG1 updated and enabled"
    ;;

update-all)
    print_header "Update All Plugins"
    echo "Checking for plugin updates..."

    # Get list of installed plugins
    PLUGINS=$(mmctl_json plugin list 2>/dev/null | grep '"id"' | cut -d'"' -f4)

    for PLUGIN in $PLUGINS; do
        echo "Checking $PLUGIN..."
        # Try to update from marketplace
        mmctl_cmd plugin marketplace install "$PLUGIN" 2>/dev/null || true
    done

    echo ""
    echo "Plugin updates complete"
    ;;

# INFO
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <plugin_id>"; exit 1; }
    print_header "Plugin Details: $ARG1"
    mmctl_cmd plugin show "$ARG1" 2>/dev/null || mmctl_json plugin list | grep -A20 "\"id\":\"$ARG1\"" || echo "Plugin not found"
    ;;

config)
    [ -z "$ARG1" ] && { echo "Usage: $0 config <plugin_id>"; exit 1; }
    print_header "Plugin Configuration: $ARG1"
    mmctl_cmd config get PluginSettings.Plugins."$ARG1" 2>/dev/null || echo "No configuration found"
    ;;

webapp)
    [ -z "$ARG1" ] && { echo "Usage: $0 webapp <plugin_id>"; exit 1; }
    print_header "Plugin WebApp Bundle: $ARG1"
    ls -la /mattermost/client/plugins/"$ARG1"* 2>/dev/null || echo "No webapp bundle found"
    ;;

# ENABLE UPLOADS
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

# SEARCH
search)
    [ -z "$ARG1" ] && { echo "Usage: $0 search <term>"; exit 1; }
    print_header "Marketplace Search: $ARG1"
    mmctl_cmd plugin marketplace list | grep -i "$ARG1" || echo "No plugins found matching: $ARG1"
    ;;

# HELP
*)
    echo "Mattermost Plugin Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list                  List all plugins (default)"
    echo "  list --json           JSON output"
    echo "  installed             List installed plugins"
    echo "  active                List active plugins"
    echo "  inactive              List inactive plugins"
    echo "  marketplace           Browse marketplace plugins"
    echo ""
    echo "MANAGEMENT:"
    echo "  install <plugin_id|file>   Install from marketplace or file"
    echo "  enable <plugin_id>         Enable plugin"
    echo "  disable <plugin_id>        Disable plugin"
    echo "  remove <plugin_id>         Remove plugin"
    echo "  update <plugin_id>         Update to latest version"
    echo "  update-all                 Update all plugins"
    echo ""
    echo "INFO:"
    echo "  get <plugin_id>       Get plugin details"
    echo "  config <plugin_id>    Show plugin config"
    echo "  webapp <plugin_id>    Check webapp bundle status"
    echo ""
    echo "SEARCH:"
    echo "  search <term>         Search marketplace"
    echo ""
    echo "SETTINGS:"
    echo "  enable-uploads        Enable plugin uploads"
    echo "  disable-uploads       Disable plugin uploads"
    echo ""
    echo "Common Plugins:"
    echo "  com.mattermost.apps              Apps Framework"
    echo "  com.mattermost.calls             Calls (Audio/Video)"
    echo "  playbooks                        Playbooks"
    echo "  focalboard                       Boards"
    echo "  com.mattermost.nps               User Satisfaction"
    echo "  github                           GitHub Integration"
    echo "  jira                             Jira Integration"
    echo "  zoom                             Zoom Integration"
    ;;
esac
