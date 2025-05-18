#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root用户权限运行" 
   exit 1
fi

# 颜色变量
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 函数：显示带颜色的信息
print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 检查域名格式
check_domain() {
    if [[ ! $1 =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "无效的域名格式"
        exit 1
    fi
}

# 检查IP版本支持
check_ip_support() {
    local has_ipv4=0
    local has_ipv6=0
    
    if [[ $(curl -s -4 icanhazip.com 2>/dev/null) ]]; then
        has_ipv4=1
    fi
    
    if [[ $(curl -s -6 icanhazip.com 2>/dev/null) ]]; then
        has_ipv6=1
    fi
    
    echo "$has_ipv4:$has_ipv6"
}

# 安装必要的软件
install_requirements() {
    print_info "正在安装必要的软件..."
    if [ -f /etc/debian_version ]; then
        apt update
        apt install -y socat curl
    elif [ -f /etc/redhat-release ]; then
        yum install -y socat curl
    else
        print_error "不支持的操作系统"
        exit 1
    fi
}

# 安装acme.sh
install_acme() {
    print_info "正在安装acme.sh..."
    curl https://get.acme.sh | sh
    ln -sf /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
    
    # 设置默认CA为Let's Encrypt
    acme.sh --set-default-ca --server letsencrypt
    
    # 注册账号
    acme.sh --register-account -m shihun1596@gmail.com
}

# 申请证书
issue_cert() {
    local domain=$1
    local ip_version=$2
    print_info "正在为域名 $domain 申请证书..."
    
    # 关闭防火墙
    if command -v ufw >/dev/null 2>&1; then
        ufw disable
    fi
    
    # 根据选择的IP版本申请证书
    case $ip_version in
        4)
            print_info "使用IPv4申请证书..."
            acme.sh --issue -d "$domain" --standalone -k ec-256
            ;;
        6)
            print_info "使用IPv6申请证书..."
            acme.sh --listen-v6 --issue -d "$domain" --standalone -k ec-256
            ;;
        *)
            print_error "无效的IP版本选择"
            exit 1
            ;;
    esac
    
    # 创建证书目录
    mkdir -p /etc/XrayR/cert
    
    # 安装证书
    acme.sh --installcert -d "$domain" --ecc \
        --key-file /etc/XrayR/cert/server.key \
        --fullchain-file /etc/XrayR/cert/server.crt
}

# 切换CA服务器
switch_ca() {
    local ca=$1
    case $ca in
        "letsencrypt")
            acme.sh --set-default-ca --server letsencrypt
            ;;
        "buypass")
            acme.sh --set-default-ca --server buypass
            ;;
        "zerossl")
            acme.sh --set-default-ca --server zerossl
            ;;
        *)
            print_error "不支持的CA服务器"
            exit 1
            ;;
    esac
}

# 主函数
main() {
    clear
    echo "=================================================="
    echo "              SSL证书一键申请脚本                  "
    echo "=================================================="
    
    # 获取域名
    read -p "请输入您的域名: " domain
    check_domain "$domain"
    
    # 检查IP支持情况
    IFS=':' read -r has_ipv4 has_ipv6 <<< "$(check_ip_support)"
    
    # 选择IP版本
    local ip_version
    if [[ $has_ipv4 -eq 1 && $has_ipv6 -eq 1 ]]; then
        echo "检测到系统同时支持IPv4和IPv6"
        echo "1. 使用IPv4申请证书"
        echo "2. 使用IPv6申请证书"
        while true; do
            read -p "请选择IP版本 [1-2]: " ip_choice
            case $ip_choice in
                1) ip_version=4; break ;;
                2) ip_version=6; break ;;
                *) print_error "无效的选择，请重新输入" ;;
            esac
        done
    elif [[ $has_ipv4 -eq 1 ]]; then
        print_info "系统仅支持IPv4，将使用IPv4申请证书"
        ip_version=4
    elif [[ $has_ipv6 -eq 1 ]]; then
        print_info "系统仅支持IPv6，将使用IPv6申请证书"
        ip_version=6
    else
        print_error "系统既不支持IPv4也不支持IPv6，无法继续"
        exit 1
    fi
    
    # 安装必要软件
    install_requirements
    
    # 安装acme.sh
    install_acme
    
    # 申请证书
    issue_cert "$domain" "$ip_version"
    
    # 如果证书申请失败，提供切换CA选项
    if [ $? -ne 0 ]; then
        print_warning "证书申请失败，是否尝试切换其他CA服务器？"
        echo "1. Let's Encrypt"
        echo "2. Buypass"
        echo "3. ZeroSSL"
        read -p "请选择CA服务器 [1-3]: " ca_choice
        
        case $ca_choice in
            1) switch_ca "letsencrypt" ;;
            2) switch_ca "buypass" ;;
            3) switch_ca "zerossl" ;;
            *) print_error "无效的选择" ; exit 1 ;;
        esac
        
        # 重新申请证书
        issue_cert "$domain" "$ip_version"
    fi
    
    if [ -f "/etc/XrayR/cert/server.crt" ] && [ -f "/etc/XrayR/cert/server.key" ]; then
        print_info "证书申请并安装成功！"
        print_info "证书路径: /etc/XrayR/cert/server.cert"
        print_info "私钥路径: /etc/XrayR/cert/server.key"
    else
        print_error "证书申请或安装失败！"
    fi
}

main 
