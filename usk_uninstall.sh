#!/bin/bash

# ==================================================
# === USK (USB Security Key) Uninstallation Script ===
# ==================================================

# This script removes the USK service files from the system.

# Configuration
USK_BIN_DIR="/usr/local/bin"
USK_RULES_DIR="/etc/udev/rules.d"
USK_ACTIVATE_SCRIPT="usk_activate.sh"
USK_DEACTIVATE_SCRIPT="usk_deactivate.sh"
USK_RULES_FILE="99-usk.rules"

# --- Functions ---

# Function to display help information
show_help() {
    cat << EOF
Usage: $0

This script uninstalls the USK (USB Security Key) background service.

NOTE: This script does NOT delete the 'virtual_key.img' file from your USB drive.
You must do that manually if you no longer need it.

Uninstallation:
  Run this script with root privileges to remove all service files.
  Example: sudo ./usk_uninstall.sh
EOF
}

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root." >&2
        exit 1
    fi
}

# --- Main Logic ---

# Check if the script is run with a flag or argument
if [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# Ensure the script is run as root
check_root

echo "--- Uninstalling USK Service ---"

# 1. Remove the core scripts from /usr/local/bin
echo "Removing activation and deactivation scripts..."
if [ -f "$USK_BIN_DIR/$USK_ACTIVATE_SCRIPT" ]; then
    rm "$USK_BIN_DIR/$USK_ACTIVATE_SCRIPT"
fi
if [ -f "$USK_BIN_DIR/$USK_DEACTIVATE_SCRIPT" ]; then
    rm "$USK_BIN_DIR/$USK_DEACTIVATE_SCRIPT"
fi
echo "Scripts removed."

# 2. Remove the udev rule file
echo "Removing udev rules file..."
if [ -f "$USK_RULES_DIR/$USK_RULES_FILE" ]; then
    rm "$USK_RULES_DIR/$USK_RULES_FILE"
fi
echo "Udev rules file removed."

# 3. Reload udev rules to apply changes
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger
echo "Udev rules reloaded."

echo "USK service uninstalled successfully."
echo "NOTE: The 'virtual_key.img' file on your USB drive has not been deleted."
echo "You can remove it manually if you no longer need it."
