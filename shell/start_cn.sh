#!/bin/bash

# ANSI 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 函数：检查包是否已安装
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
            echo -e "${RED}不支持的操作系统:${NC} $OS"
            exit 1
            ;;
    esac
}

# 函数：安装必要的软件包
install_packages() {
    local packages=("git" "python3" "wget")

    # 检查并安装缺失的软件包
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            echo "$package 未安装。正在安装..."
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

# 函数：检查是否安装了 sing-box
check_sing_box_installed() {
    if ! command -v sing-box &>/dev/null; then
        echo -e "${RED}未安装 sing-box，请先安装 sing-box。${NC}"
        exit 1
    fi
}

# 函数：检查脚本是否已安装
check_script_installed() {
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo -e "${RED}脚本未安装，无需卸载。${NC}"
        exit 1
    fi
}

# 函数：生成 rule_set.json 文件
generate_rule_set() {
    TEMP_DIR="/tmp/generate_rule_set_cache"
    mkdir -p "$TEMP_DIR"

    # 下载 generate_rule_set.py 到缓存目录
    SCRIPT_URL="https://raw.githubusercontent.com/ReyReyy/sing-rule-set-json-auto-generate/main/generate_rule_set.py"
    SCRIPT_PATH="$TEMP_DIR/generate_rule_set.py"

    wget "$SCRIPT_URL" -O "$SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载 generate_rule_set.py 失败${NC}"
        exit 1
    fi

    # 授予脚本执行权限
    chmod +x "$SCRIPT_PATH"

    # 运行脚本
    python3 "$SCRIPT_PATH"
    RUN_STATUS=$?

    if [ $RUN_STATUS -ne 0 ]; then
        echo -e "${RED}运行 generate_rule_set.py 时出错，退出状态:${NC} $RUN_STATUS"
        exit $RUN_STATUS
    fi

}

# 函数：安装脚本并设置自动更新
install_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # 如果脚本已安装，提示用户
    if [ -d "$AUTO_UPDATE_DIR" ]; then
        echo -e "${GREEN}脚本已安装，无需再次安装。${NC}"
        exit 1
    fi

    # 移动脚本到 auto_update 目录
    mkdir "$AUTO_UPDATE_DIR"
    sudo mv "$SCRIPT_PATH" "$AUTO_UPDATE_DIR/"

    # 将每日更新任务添加到 crontab
    CRON_JOB="0 0 * * * /usr/bin/python3 $AUTO_UPDATE_DIR/generate_rule_set.py"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

}

# 函数：卸载脚本并移除相关文件
uninstall_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # 检查脚本是否安装
    check_script_installed

    # 移除脚本目录
    sudo rm -rf "$AUTO_UPDATE_DIR"

    # 从 crontab 中移除任务
    crontab -l | grep -v "$AUTO_UPDATE_DIR/generate_rule_set.py" | crontab -

    # 删除其他相关文件和目录
    sudo rm -f /etc/sing-box/rule_set.json
    sudo rm -rf /etc/sing-box/sing-geosite/
    sudo rm -rf /etc/sing-box/sing-geoip/

}

# 函数：清理缓存文件
cleanup_cache() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 函数：生成
action_generate() {
    check_sing_box_installed
    generate_rule_set
    cleanup_cache
    echo -e "${GREEN}生成完成。${NC}"
}

# 函数：安装
action_install() {
    check_sing_box_installed
    if [ -d "/etc/sing-box/auto_update" ]; then
        echo -e "${RED}脚本已安装，无需再次安装。${NC}"
    else
        generate_rule_set
        install_script
        cleanup_cache
        echo -e "${GREEN}安装完成。${NC}"
    fi
}

# 函数：卸载
action_uninstall() {
    check_script_installed
    uninstall_script
    echo -e "${GREEN}卸载完成，相关文件已移除。${NC}"
}

# 函数：显示用户界面
show_user_interface() {
    # 检查脚本是否安装并显示状态
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo -e "状态: ${RED}未安装${NC}"
    else
        echo -e "状态: ${GREEN}已安装${NC}"
    fi

    echo "请选择要执行的操作:"
    echo "1) 生成"
    echo "2) 安装"
    echo "3) 卸载"
    read -rp "选择 (1, 2, 或 3): " ACTION_CHOICE

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
            echo -e "${RED}无效选择，请选择 1, 2, 或 3。${NC}"
            exit 1
            ;;
    esac
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以 root 身份运行或使用 sudo。${NC}"
  exit 1
fi

# 检测系统版本并选择包管理器
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}无法检测操作系统版本${NC}"
    exit 1
fi

# 安装 git, python3 和 wget
install_packages

# 处理脚本参数
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
        echo -e "${RED}无效参数。${NC}"
        exit 1
        ;;
esac

# 脚本执行结束后自动删除
SCRIPT_PATH="$(realpath "$0")"
rm -f "$SCRIPT_PATH"
