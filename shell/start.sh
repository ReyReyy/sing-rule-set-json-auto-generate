#!/bin/bash

# Function: Check if a package is installed
is_package_installed() {
    local package=$1
    case "$OS" in
        ubuntu|debian)
            dpkg -l | grep -qw "$package"
            ;;
        centos|rhel|fedora)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        arch)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}

# Function: Install necessary packages
install_packages() {
    local packages=("git" "python3" "wget")

    # Check and install missing packages
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            echo "$package is not installed. Installing..."
            case "$OS" in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y "$package"
                    ;;
                centos|rhel|fedora)
                    if command -v dnf >/dev/null 2>&1; then
                        sudo dnf install -y "$package"
                    else
                        sudo yum install -y "$package"
                    fi
                    ;;
                arch)
                    sudo pacman -Sy --noconfirm "$package"
                    ;;
            esac
        fi
    done
}

# Function: Check if sing-box is installed
check_sing_box_installed() {
    if ! command -v sing-box &>/dev/null; then
        echo "sing-box not detected, please install sing-box before proceeding."
        exit 1
    fi
}

# Function: Check if the script is already installed
check_script_installed() {
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo "Script not detected, no need to uninstall."
        exit 1
    fi
}

# Function: Generate the rule_set.json file
generate_rule_set() {
    TEMP_DIR="/tmp/generate_rule_set_cache"
    mkdir -p "$TEMP_DIR"

    # Download generate_rule_set.py to the cache directory
    SCRIPT_URL="https://raw.githubusercontent.com/ReyReyy/sing-rule-set-json-auto-generate/main/generate_rule_set.py"
    SCRIPT_PATH="$TEMP_DIR/generate_rule_set.py"

    wget "$SCRIPT_URL" -O "$SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to download generate_rule_set.py"
        exit 1
    fi

    # Grant execute permissions to the script
    chmod +x "$SCRIPT_PATH"

    # Run the script
    python3 "$SCRIPT_PATH"
    RUN_STATUS=$?

    if [ $RUN_STATUS -ne 0 ]; then
        echo "An error occurred while running generate_rule_set.py, exit status: $RUN_STATUS"
        exit $RUN_STATUS
    fi

    echo "Generation completed."
}

# Function: Install the script and set up auto-update
install_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # If the script is already installed, prompt the user
    if [ -d "$AUTO_UPDATE_DIR" ]; then
        echo "Script is already installed, no need to install again."
        exit 1
    fi

    # Move the script to the auto_update directory
    mkdir "$AUTO_UPDATE_DIR"
    sudo mv "$SCRIPT_PATH" "$AUTO_UPDATE_DIR/"

    # Add a daily update task to crontab
    CRON_JOB="0 0 * * * /usr/bin/python3 $AUTO_UPDATE_DIR/generate_rule_set.py"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo "Installation completed."
}

# Function: Uninstall the script and remove related files
uninstall_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # Check if the script is installed
    check_script_installed

    # Remove the script directory
    sudo rm -rf "$AUTO_UPDATE_DIR"

    # Remove the task from crontab
    crontab -l | grep -v "$AUTO_UPDATE_DIR/generate_rule_set.py" | crontab -

    # Delete other related files and directories
    sudo rm -f /etc/sing-box/rule_set.json
    sudo rm -rf /etc/sing-box/sing-geosite/
    sudo rm -rf /etc/sing-box/sing-geoip/

    echo "Uninstallation completed, related files have been removed."
}

# Function: Clean up cache files
cleanup_cache() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        # echo "Temporary files have been deleted."
    fi
}

# Function: Display the user interface
show_user_interface() {
    echo "Please select the operation to perform:"
    echo "1) Generate"
    echo "2) Install"
    echo "3) Uninstall"
    read -rp "Select (1, 2, or 3): " ACTION_CHOICE

    case "$ACTION_CHOICE" in
        1)
            check_sing_box_installed
            generate_rule_set
            cleanup_cache
            ;;
        2)
            check_sing_box_installed
            if [ -d "/etc/sing-box/auto_update" ]; then
                echo "Script is already installed, no need to install again."
            else
                generate_rule_set
                install_script
                cleanup_cache
            fi
            ;;
        3)
            check_script_installed
            uninstall_script
            ;;
        *)
            echo "Invalid selection, please choose 1, 2, or 3."
            exit 1
            ;;
    esac
}

# Detect system version and select package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unable to detect operating system version"
    exit 1
fi

# Install git, python3, and wget
install_packages

# Handle script arguments
case "$1" in
    g|generate)
        check_sing_box_installed
        generate_rule_set
        cleanup_cache
        ;;
    i|install)
        check_sing_box_installed
        if [ -d "/etc/sing-box/auto_update" ]; then
            echo "Script is already installed, no need to install again."
        else
            generate_rule_set
            install_script
            cleanup_cache
        fi
        ;;
    u|uninstall)
        check_script_installed
        uninstall_script
        ;;
    m|menu|"")
        show_user_interface
        ;;
    *)
        echo "Invalid parameter."
        exit 1
        ;;
esac

# Automatically delete the script after execution
SCRIPT_PATH="$(realpath "$0")"
rm -f "$SCRIPT_PATH"
