#!/bin/bash

# ANSI Color
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

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
            echo -e "${RED}Unsupported operating system:${NC} $OS"
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
        echo -e "${RED}sing-box not installed, please install sing-box before proceeding.${NC}"
        exit 1
    fi
}

# Function: Check if the script is already installed
check_script_installed() {
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo -e "${RED}Script not installed, no need to uninstall.${NC}"
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
        echo -e "${RED}Failed to download generate_rule_set.py${NC}"
        exit 1
    fi

    # Grant execute permissions to the script
    chmod +x "$SCRIPT_PATH"

    # Run the script
    python3 "$SCRIPT_PATH"
    RUN_STATUS=$?

    if [ $RUN_STATUS -ne 0 ]; then
        echo -e "${RED}An error occurred while running generate_rule_set.py, exit status:${NC} $RUN_STATUS"
        exit $RUN_STATUS
    fi

}

# Function: Install the script and set up auto-update
install_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # If the script is already installed, prompt the user
    if [ -d "$AUTO_UPDATE_DIR" ]; then
        echo -e "${GREEN}Script is already installed, no need to install again.${NC}"
        exit 1
    fi

    # Move the script to the auto_update directory
    mkdir "$AUTO_UPDATE_DIR"
    sudo mv "$SCRIPT_PATH" "$AUTO_UPDATE_DIR/"

    # Add a daily update task to crontab
    CRON_JOB="0 0 * * * /usr/bin/python3 $AUTO_UPDATE_DIR/generate_rule_set.py"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

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

}

# Function: Clean up cache files
cleanup_cache() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        # echo "Temporary files have been deleted."
    fi
}

# Function: Generate
action_generate() {
    check_sing_box_installed
    generate_rule_set
    cleanup_cache
    echo -e "${GREEN}Generation completed.${NC}"
}

# Function: Install
action_install() {
     check_sing_box_installed
    if [ -d "/etc/sing-box/auto_update" ]; then
        echo -e "${RED}Script is already installed, no need to install again.${NC}"
    else
        generate_rule_set
        install_script
        cleanup_cache
        echo -e "${GREEN}Installation completed.${NC}"
    fi
}

# Function: uninstall
action_uninstall() {
    check_script_installed
    uninstall_script
    echo -e "${GREEN}Uninstallation completed, related files have been removed.${NC}"
}

# Function: Display the user interface
show_user_interface() {
    # Check if script installed and show status
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo -e "Status: ${RED}Not installed${NC}"
    else
        echo -e "Status: ${GREEN}Installed${NC}"
    fi

    echo "Please select the operation to perform:"
    echo "1) Generate"
    echo "2) Install"
    echo "3) Uninstall"
    read -rp "Select (1, 2, or 3): " ACTION_CHOICE

    case "$ACTION_CHOICE" in
        1)
            action_generate
            ;;
        2)
            action_install
            ;;
        3)
            action_uninstall
            ;;
        *)
            echo -e "${RED}Invalid selection, please choose 1, 2, or 3.${NC}"
            exit 1
            ;;
    esac
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or use sudo.${NC}"
  exit 1
fi

# Detect system version and select package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Unable to detect operating system version${NC}"
    exit 1
fi

# Install git, python3, and wget
install_packages

# Handle script arguments
case "$1" in
    g|generate)
        action_generate
        ;;
    i|install)
        action_install
        ;;
    u|uninstall)
        action_uninstall
        ;;
    m|menu|"")
        show_user_interface
        ;;
    *)
        echo -e "${RED}Invalid parameter.${NC}"
        exit 1
        ;;
esac

# Automatically delete the script after execution
SCRIPT_PATH="$(realpath "$0")"
rm -f "$SCRIPT_PATH"
