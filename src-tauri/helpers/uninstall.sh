#!/bin/bash
#
# WeckPilot Wake Helper - Uninstaller
# Removes the wake helper daemon and binary.
# Must be run with root privileges.
#

set -e

HELPER_NAME="WeckPilotWakeHelper"
PLIST_NAME="de.little-tools.weckpilot.wake-helper.plist"
INSTALL_DIR="/usr/local/bin"
PLIST_DIR="/Library/LaunchDaemons"
SHARED_DIR="/Users/Shared/WeckPilot"
LEGACY_HELPER_NAME="AlarmMasterWakeHelper"
LEGACY_PLIST_NAME="com.alarmmaster.wake-helper.plist"
LEGACY_SHARED_DIR="/Users/Shared/AlarmMaster"

echo "=== WeckPilot Wake Helper Uninstaller ==="

# 1. Cancel any scheduled wake events
if [ -f "$SHARED_DIR/state.json" ]; then
    echo "Cancelling scheduled wake events..."
    # Read last scheduled wake from state
    LAST_WAKE=$(python3 -c "import json; d=json.load(open('$SHARED_DIR/state.json')); print(d.get('lastScheduledWake',''))" 2>/dev/null || true)
    if [ -n "$LAST_WAKE" ]; then
        pmset schedule cancel wakeorpoweron "$LAST_WAKE" 2>/dev/null || true
        echo "Cancelled wake event: $LAST_WAKE"
    fi
fi

# 2. Unload daemon
echo "Unloading daemon..."
launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl unload "$PLIST_DIR/$LEGACY_PLIST_NAME" 2>/dev/null || true

# 3. Remove files
echo "Removing files..."
rm -f "$INSTALL_DIR/$HELPER_NAME"
rm -f "$PLIST_DIR/$PLIST_NAME"
rm -f "$INSTALL_DIR/$LEGACY_HELPER_NAME"
rm -f "$PLIST_DIR/$LEGACY_PLIST_NAME"

# 4. Optionally clean shared directory
rm -f "$SHARED_DIR/state.json"
rm -f "$SHARED_DIR/schedule.json"
rm -f "$SHARED_DIR/helper.log"
rm -f "$SHARED_DIR/launchd-stdout.log"
rm -f "$SHARED_DIR/launchd-stderr.log"
rmdir "$SHARED_DIR" 2>/dev/null || true
rm -f "$LEGACY_SHARED_DIR/state.json"
rm -f "$LEGACY_SHARED_DIR/schedule.json"
rm -f "$LEGACY_SHARED_DIR/helper.log"
rm -f "$LEGACY_SHARED_DIR/launchd-stdout.log"
rm -f "$LEGACY_SHARED_DIR/launchd-stderr.log"
rmdir "$LEGACY_SHARED_DIR" 2>/dev/null || true

echo ""
echo "=== Uninstallation Complete ==="
echo "Wake helper has been removed."
