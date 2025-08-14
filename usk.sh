#!/bin/bash

# ===============================================
# === USK (USB Security Key) Installation Script ===
# ===============================================

# Configuration
USK_BIN_DIR="/usr/local/bin"
USK_RULES_DIR="/etc/udev/rules.d"
USK_KEY_FILENAME="virtual_key.img"
MOUNT_NAME="virtual_key"
MOUNT_POINT="/media/virtual_key"

# --- Functions ---

# Function to display help information
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script installs and manages the USK (USB Security Key) tool.

Options:
  --install           Install the USK background service and scripts.
  --create-key        Create the encrypted key file on a connected USB drive.
  --help              Show this help message.

Installation:
  Run with '--install' to set up the system. This requires root privileges.
  Example: sudo $0 --install

Create Key:
  Run with '--create-key' after installation to create your security key file.
  Example: sudo $0 --create-key
EOF
}

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root." >&2
        exit 1
    fi
}

# --- Installation Logic ---

# This function creates and installs the core activation and deactivation scripts.
install_service() {
    check_root

    echo "--- Installing USK Service ---"

    # Create the activation script
    cat > "$USK_BIN_DIR/usk_activate.sh" << 'EOF'
#!/bin/bash
# USK Activation Script - Automatically triggered by udev.
# Do not run this script manually.

# Configuration
KEY_FILENAME="virtual_key.img"
MOUNT_NAME="virtual_key"
MOUNT_POINT="/media/virtual_key"

# Check if a device path was provided by udev
USB_MOUNT_PATH="$1"
if [ -z "$USB_MOUNT_PATH" ]; then
    exit 0
fi

KEY_FILE_PATH="$USB_MOUNT_PATH/$KEY_FILENAME"

# Exit if the key file does not exist on the device.
[ ! -f "$KEY_FILE_PATH" ] && exit 0

# Get the unique motherboard UUID as the passphrase.
DEVICE_FINGERPRINT=$(dmidecode -s system-uuid 2>/dev/null)
if [ -z "$DEVICE_FINGERPRINT" ]; then
    echo "USK: Error - Could not retrieve device fingerprint." >&2
    exit 1
fi

PASSPHRASE="$DEVICE_FINGERPRINT"

# Use cryptsetup to open the LUKS container
echo "$PASSPHRASE" | cryptsetup luksOpen "$KEY_FILE_PATH" "$MOUNT_NAME" --allow-discards -d - >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "USK: Failed to open LUKS container. Incorrect passphrase or corrupt file." >&2
    exit 1
fi

# Mount the decrypted device
mkdir -p "$MOUNT_POINT"
mount /dev/mapper/"$MOUNT_NAME" "$MOUNT_POINT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "USK: Virtual key mounted at $MOUNT_POINT."
fi
EOF

    # Create the deactivation script
    cat > "$USK_BIN_DIR/usk_deactivate.sh" << 'EOF'
#!/bin/bash
# USK Deactivation Script - Automatically triggered by udev.
# Do not run this script manually.

# Configuration
MOUNT_NAME="virtual_key"
MOUNT_POINT="/media/virtual_key"

# Check if the device is mounted before attempting to unmount.
if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT" >/dev/null 2>&1
    cryptsetup luksClose "$MOUNT_NAME" >/dev/null 2>&1
    echo "USK: Virtual key deactivated."
fi
EOF

    # Make scripts executable
    chmod +x "$USK_BIN_DIR/usk_activate.sh"
    chmod +x "$USK_BIN_DIR/usk_deactivate.sh"
    echo "Core scripts created and made executable."

    # Create the udev rule file
    cat > "$USK_RULES_DIR/99-usk.rules" << EOF
# Udev rules for USK (USB Security Key)
ACTION=="add", SUBSYSTEM=="usb", RUN+="$USK_BIN_DIR/usk_activate.sh %E{MOUNT_POINT}"
ACTION=="remove", SUBSYSTEM=="usb", RUN+="$USK_BIN_DIR/usk_deactivate.sh"
EOF
    echo "Udev rules created."

    # Reload udev rules to apply changes
    udevadm control --reload-rules
    udevadm trigger
    echo "Udev rules reloaded. USK service installed successfully."
    echo "Now, you can create a key using: sudo $0 --create-key"
}

# --- Key Creation Logic ---

create_key() {
    check_root

    echo "--- Creating USK Key ---"
    echo "Please plug in the USB drive you want to use for the key."
    read -p "Press Enter when the USB drive is plugged in..."

    # List available partitions for the user
    echo "Detecting USB partitions..."
    lsblk -p -o NAME,SIZE,MOUNTPOINT | grep -E '^/dev/sd|/dev/nvme'

    read -p "Enter the mount point of the USB drive (e.g., /media/user/MYUSB): " USB_MOUNT_PATH

    if [ ! -d "$USB_MOUNT_PATH" ]; then
        echo "Error: The specified path is not a valid directory or is not mounted." >&2
        exit 1
    fi

    # Create the blank file for the container
    echo "Creating a 50MB encrypted file '${USK_KEY_FILENAME}' on the USB drive..."
    dd if=/dev/urandom of="$USB_MOUNT_PATH/$USK_KEY_FILENAME" bs=1M count=50 iflag=fullblock status=progress
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create the key file. Check permissions or disk space." >&2
        exit 1
    fi

    # Get the unique motherboard UUID as the passphrase
    DEVICE_FINGERPRINT=$(dmidecode -s system-uuid 2>/dev/null)
    if [ -z "$DEVICE_FINGERPRINT" ]; then
        echo "Error: Could not retrieve device fingerprint. Aborting." >&2
        exit 1
    fi

    echo "The key will be encrypted using your motherboard's unique ID."
    echo "Formatting the file as a LUKS container..."

    # Format the file with LUKS using the UUID as the key
    echo "$DEVICE_FINGERPRINT" | cryptsetup luksFormat "$USB_MOUNT_PATH/$USK_KEY_FILENAME" --key-file=- --allow-discards -q >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to format the file as LUKS. Check that 'cryptsetup' is installed." >&2
        rm "$USB_MOUNT_PATH/$USK_KEY_FILENAME"
        exit 1
    fi

    echo "Success! The encrypted key file has been created."
    echo "Plug the USB in and out to test the automatic mounting."
}

# --- Main Script Execution ---

case "$1" in
    --install)
        install_service
        ;;
    --create-key)
        create_key
        ;;
    --help)
        show_help
        ;;
    *)
        echo "Invalid option. Use --help for usage information."
        show_help
        exit 1
        ;;
esac
