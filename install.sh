#!/bin/bash

# 颜色变量
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[错误] 此脚本必须以root用户权限运行${NC}"
    echo -e "请使用 ${GREEN}sudo -i${NC} 切换到root用户后再运行脚本"
    exit 1
fi

# 安装依赖
if [ -f /etc/debian_version ]; then
    apt update
    apt install -y curl wget
elif [ -f /etc/redhat-release ]; then
    yum install -y curl wget
fi

# GitHub 仓库信息
GITHUB_RAW_URL="https://raw.githubusercontent.com/你的用户名/你的仓库名/main"
SCRIPT_NAME="install_cert.sh"

# 下载主脚本
echo -e "${GREEN}[信息] 正在下载证书安装脚本...${NC}"
curl -fsSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$SCRIPT_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 脚本下载失败，请检查网络连接或GitHub地址是否正确${NC}"
    exit 1
fi

# 添加执行权限
chmod +x "$SCRIPT_NAME"

# 执行主脚本
echo -e "${GREEN}[信息] 开始安装证书...${NC}"
./"$SCRIPT_NAME"

# 清理下载的脚本
rm -f "$SCRIPT_NAME" 
