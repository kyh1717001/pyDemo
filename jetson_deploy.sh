#!/bin/bash

# Jetson自动化部署脚本
# 用法: ./jetson_deploy.sh <目标IP> <新IP地址> <下载URL> <Git仓库URL> <安装脚本路径>

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo "使用说明:"
    echo "  $0 <目标IP> <新IP地址> <下载URL> <Git仓库URL> <安装脚本路径>"
    echo ""
    echo "参数说明:"
    echo "  目标IP        - Jetson设备当前IP地址"
    echo "  新IP地址      - 要设置的新IP地址（可选，输入'skip'跳过）"
    echo "  下载URL       - 要下载的zip文件URL（可选，输入'skip'跳过）"
    echo "  Git仓库URL    - Git仓库地址"
    echo "  安装脚本路径  - 安装脚本在目标机器上的路径"
    echo ""
    echo "示例:"
    echo "  $0 192.168.1.100 192.168.1.101 https://example.com/file.zip https://github.com/user/repo.git /home/nvidia/install.sh"
    echo "  $0 192.168.1.100 skip https://example.com/file.zip https://github.com/user/repo.git /home/nvidia/install.sh"
}

# 检查参数
if [ $# -lt 5 ]; then
    log_error "参数不足"
    show_usage
    exit 1
fi

TARGET_IP="$1"
NEW_IP="$2"
DOWNLOAD_URL="$3"
GIT_REPO="$4"
INSTALL_SCRIPT="$5"

# SSH配置
SSH_USER="${SSH_USER:-nvidia}"  # 默认用户为nvidia
SSH_PORT="${SSH_PORT:-22}"      # 默认端口22
SSH_KEY="${SSH_KEY:-}"          # SSH密钥路径（可选）

log_info "开始部署到Jetson设备: $TARGET_IP"

# 构建SSH命令前缀
build_ssh_cmd() {
    local ssh_cmd="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    ssh_cmd="$ssh_cmd -p $SSH_PORT $SSH_USER@$TARGET_IP"
    echo "$ssh_cmd"
}

# 测试SSH连接
test_ssh_connection() {
    log_info "测试SSH连接到 $TARGET_IP..."
    local ssh_cmd=$(build_ssh_cmd)
    
    if $ssh_cmd "echo 'SSH连接成功'" >/dev/null 2>&1; then
        log_success "SSH连接测试成功"
        return 0
    else
        log_error "SSH连接失败，请检查："
        echo "  1. 目标IP地址是否正确"
        echo "  2. SSH服务是否启动"
        echo "  3. 网络连接是否正常"
        echo "  4. 用户名密码是否正确"
        return 1
    fi
}

# 修改IP地址
change_ip_address() {
    if [ "$NEW_IP" = "skip" ]; then
        log_info "跳过IP地址修改"
        return 0
    fi

    log_info "修改IP地址为: $NEW_IP"
    local ssh_cmd=$(build_ssh_cmd)
    
    # 创建网络配置脚本
    local network_script=$(cat << 'EOF'
#!/bin/bash

NEW_IP="$1"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$INTERFACE" ]; then
    echo "错误: 无法找到默认网络接口"
    exit 1
fi

echo "检测到网络接口: $INTERFACE"

# 备份当前网络配置
sudo cp /etc/netplan/*.yaml /etc/netplan/backup_$(date +%Y%m%d_%H%M%S).yaml 2>/dev/null || true

# 获取当前网关和DNS
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
DNS_SERVERS=$(systemd-resolve --status | grep "DNS Servers" | awk '{print $3}' | head -n1)
if [ -z "$DNS_SERVERS" ]; then
    DNS_SERVERS="8.8.8.8"
fi

# 创建新的netplan配置
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null << NETPLAN_EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $NEW_IP/24
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS, 8.8.4.4]
NETPLAN_EOF

echo "网络配置已更新"
echo "应用新配置..."

# 应用配置
sudo netplan apply

echo "IP地址修改完成: $NEW_IP"
echo "请注意：SSH连接可能会断开，需要使用新IP重新连接"
EOF
)

    # 执行网络配置修改
    echo "$network_script" | $ssh_cmd "cat > /tmp/change_ip.sh && chmod +x /tmp/change_ip.sh && /tmp/change_ip.sh '$NEW_IP'"
    
    if [ $? -eq 0 ]; then
        log_success "IP地址修改完成"
        log_warning "SSH连接可能已断开，等待5秒后使用新IP重新连接..."
        sleep 5
        TARGET_IP="$NEW_IP"  # 更新目标IP
    else
        log_error "IP地址修改失败"
        return 1
    fi
}

# 下载并解压ZIP文件
download_and_extract() {
    if [ "$DOWNLOAD_URL" = "skip" ]; then
        log_info "跳过文件下载"
        return 0
    fi

    log_info "下载并解压文件: $DOWNLOAD_URL"
    local ssh_cmd=$(build_ssh_cmd)
    
    local download_script=$(cat << 'EOF'
#!/bin/bash

DOWNLOAD_URL="$1"
DOWNLOAD_DIR="$HOME/downloads"
FILENAME=$(basename "$DOWNLOAD_URL")

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

echo "开始下载: $DOWNLOAD_URL"

# 下载文件
if command -v wget >/dev/null 2>&1; then
    wget -O "$FILENAME" "$DOWNLOAD_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$FILENAME" "$DOWNLOAD_URL"
else
    echo "错误: 系统中没有wget或curl"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "下载失败"
    exit 1
fi

echo "下载完成: $FILENAME"

# 检查文件类型并解压
if [[ "$FILENAME" == *.zip ]]; then
    echo "解压ZIP文件..."
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$FILENAME"
    else
        echo "错误: 系统中没有unzip工具"
        echo "尝试安装unzip..."
        sudo apt-get update && sudo apt-get install -y unzip
        unzip -o "$FILENAME"
    fi
elif [[ "$FILENAME" == *.tar.gz ]] || [[ "$FILENAME" == *.tgz ]]; then
    echo "解压TAR.GZ文件..."
    tar -xzf "$FILENAME"
elif [[ "$FILENAME" == *.tar ]]; then
    echo "解压TAR文件..."
    tar -xf "$FILENAME"
else
    echo "警告: 未知的文件格式，跳过解压"
fi

echo "文件处理完成"
ls -la
EOF
)

    echo "$download_script" | $ssh_cmd "cat > /tmp/download_extract.sh && chmod +x /tmp/download_extract.sh && /tmp/download_extract.sh '$DOWNLOAD_URL'"
    
    if [ $? -eq 0 ]; then
        log_success "文件下载和解压完成"
    else
        log_error "文件下载或解压失败"
        return 1
    fi
}

# Git拉取代码
git_clone_or_pull() {
    log_info "Git操作: $GIT_REPO"
    local ssh_cmd=$(build_ssh_cmd)
    
    local git_script=$(cat << 'EOF'
#!/bin/bash

GIT_REPO="$1"
PROJECT_DIR="$HOME/projects"
REPO_NAME=$(basename "$GIT_REPO" .git)

# 创建项目目录
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "Git仓库: $GIT_REPO"
echo "项目名称: $REPO_NAME"

# 检查Git是否安装
if ! command -v git >/dev/null 2>&1; then
    echo "Git未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y git
fi

# 检查项目是否已存在
if [ -d "$REPO_NAME" ]; then
    echo "项目目录已存在，执行pull操作..."
    cd "$REPO_NAME"
    
    # 检查是否是Git仓库
    if [ -d ".git" ]; then
        echo "更新现有仓库..."
        git fetch origin
        git reset --hard origin/main || git reset --hard origin/master
        git pull
    else
        echo "目录存在但不是Git仓库，删除后重新克隆..."
        cd ..
        rm -rf "$REPO_NAME"
        git clone "$GIT_REPO"
    fi
else
    echo "克隆新仓库..."
    git clone "$GIT_REPO"
fi

cd "$REPO_NAME"
echo "当前目录: $(pwd)"
echo "Git操作完成"
ls -la
EOF
)

    echo "$git_script" | $ssh_cmd "cat > /tmp/git_operations.sh && chmod +x /tmp/git_operations.sh && /tmp/git_operations.sh '$GIT_REPO'"
    
    if [ $? -eq 0 ]; then
        log_success "Git代码拉取完成"
    else
        log_error "Git操作失败"
        return 1
    fi
}

# 运行安装脚本
run_install_script() {
    log_info "运行安装脚本: $INSTALL_SCRIPT"
    local ssh_cmd=$(build_ssh_cmd)
    
    # 检查安装脚本是否存在并运行
    $ssh_cmd "
        if [ -f '$INSTALL_SCRIPT' ]; then
            echo '找到安装脚本: $INSTALL_SCRIPT'
            chmod +x '$INSTALL_SCRIPT'
            echo '开始执行安装脚本...'
            cd \$(dirname '$INSTALL_SCRIPT')
            '$INSTALL_SCRIPT'
        else
            echo '错误: 安装脚本不存在: $INSTALL_SCRIPT'
            echo '当前目录内容:'
            find \$HOME -name '*.sh' -type f 2>/dev/null | head -10
            exit 1
        fi
    "
    
    if [ $? -eq 0 ]; then
        log_success "安装脚本执行完成"
    else
        log_error "安装脚本执行失败"
        return 1
    fi
}

# 主执行流程
main() {
    log_info "========== Jetson自动化部署开始 =========="
    
    # 1. 测试SSH连接
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # 2. 修改IP地址
    if ! change_ip_address; then
        log_warning "IP地址修改失败，继续执行其他步骤..."
    fi
    
    # 等待网络重新连接（如果修改了IP）
    if [ "$NEW_IP" != "skip" ] && [ "$NEW_IP" != "$1" ]; then
        log_info "等待网络重新连接..."
        sleep 10
        # 重新测试连接
        if ! test_ssh_connection; then
            log_error "使用新IP连接失败"
            exit 1
        fi
    fi
    
    # 3. 下载并解压文件
    if ! download_and_extract; then
        log_warning "文件下载失败，继续执行其他步骤..."
    fi
    
    # 4. Git拉取代码
    if ! git_clone_or_pull; then
        log_error "Git操作失败"
        exit 1
    fi
    
    # 5. 运行安装脚本
    if ! run_install_script; then
        log_error "安装脚本执行失败"
        exit 1
    fi
    
    log_success "========== 部署完成 =========="
    log_info "所有步骤已成功完成！"
}

# 运行主函数
main "$@"