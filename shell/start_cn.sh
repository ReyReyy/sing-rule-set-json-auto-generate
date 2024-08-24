#!/bin/bash

# 函数：检查软件包是否已安装
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
            echo "不支持的操作系统：$OS"
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
            echo "$package 未安装，正在安装..."
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
        echo "未检测到 sing-box，请先安装 sing-box。"
        exit 1
    fi
}

# 函数：检查脚本是否已安装
check_script_installed() {
    if [ ! -d "/etc/sing-box/auto_update" ]; then
        echo "未检测到脚本，无需卸载。"
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
        echo "下载 generate_rule_set.py 失败"
        exit 1
    fi

    # 给予脚本执行权限
    chmod +x "$SCRIPT_PATH"

    # 运行脚本
    python3 "$SCRIPT_PATH"
    RUN_STATUS=$?

    if [ $RUN_STATUS -ne 0 ]; then
        echo "运行 generate_rule_set.py 时发生错误，退出状态：$RUN_STATUS"
        exit $RUN_STATUS
    fi

    echo "生成完成。"
}

# 函数：安装脚本并设置自动更新
install_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # 如果脚本已安装，提示用户
    if [ -d "$AUTO_UPDATE_DIR" ]; then
        echo "脚本已安装，无需再次安装。"
        exit 1
    fi

    # 移动脚本到 auto_update 目录
    mkdir "$AUTO_UPDATE_DIR"
    sudo mv "$SCRIPT_PATH" "$AUTO_UPDATE_DIR/"

    # 在 crontab 中添加每日更新任务
    CRON_JOB="0 0 * * * /usr/bin/python3 $AUTO_UPDATE_DIR/generate_rule_set.py"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo "安装完成。"
}

# 函数：卸载脚本并删除相关文件
uninstall_script() {
    AUTO_UPDATE_DIR="/etc/sing-box/auto_update"

    # 检查是否已安装脚本
    check_script_installed

    # 删除脚本目录
    sudo rm -rf "$AUTO_UPDATE_DIR"

    # 从 crontab 中删除任务
    crontab -l | grep -v "$AUTO_UPDATE_DIR/generate_rule_set.py" | crontab -

    # 删除其他相关文件和目录
    sudo rm -f /etc/sing-box/rule_set.json
    sudo rm -rf /etc/sing-box/sing-geosite/
    sudo rm -rf /etc/sing-box/sing-geoip/

    echo "卸载完成。"
}

# 函数：清理缓存文件
cleanup_cache() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        # echo "临时文件已删除。"
    fi
}

# 函数：显示用户界面
show_user_interface() {
    echo "请选择要执行的操作："
    echo "1) 生成"
    echo "2) 安装"
    echo "3) 卸载"
    read -rp "选择 (1, 2 或 3): " ACTION_CHOICE

    case "$ACTION_CHOICE" in
        1)
            check_sing_box_installed
            generate_rule_set
            cleanup_cache
            ;;
        2)
            check_sing_box_installed
            if [ -d "/etc/sing-box/auto_update" ]; then
                echo "脚本已安装，无需再次安装。"
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
            echo "无效的选择，请选择 1, 2 或 3。"
            exit 1
            ;;
    esac
}

# 检测系统版本并选择包管理器
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法检测操作系统版本"
    exit 1
fi

# 安装 git、python3 和 wget
install_packages

# 处理脚本参数
case "$1" in
    g|generate)
        check_sing_box_installed
        generate_rule_set
        cleanup_cache
        ;;
    i|install)
        check_sing_box_installed
        if [ -d "/etc/sing-box/auto_update" ]; then
            echo "脚本已安装，无需再次安装。"
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
        echo "无效的参数。"
        exit 1
        ;;
esac

# 脚本执行结束后自动删除脚本
SCRIPT_PATH="$(realpath "$0")"
rm -f "$SCRIPT_PATH"
