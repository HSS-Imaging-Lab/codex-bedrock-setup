#!/usr/bin/env bash
# Change the launchd refresh cadence.
# Usage: bash ~/.codex/scripts/codex-bedrock-set-interval.sh <seconds>
#        3000 = 50 minutes (normal), 30 = short test (do not leave running)
set -euo pipefail
SECS="${1:?seconds}"
PLIST_NAME="com.hss.codex-bedrock-refresh"
PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
/usr/libexec/PlistBuddy -c "Set :StartInterval $SECS" "$PLIST"
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "StartInterval now $SECS s"
launchctl print "gui/$(id -u)/$PLIST_NAME" | grep -E 'state|interval' || true
