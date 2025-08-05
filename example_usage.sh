#!/bin/bash

# Jetson部署脚本使用示例

echo "======== Jetson自动化部署脚本使用示例 ========"

# 加载配置（可选）
if [ -f "jetson_config.env" ]; then
    echo "加载配置文件..."
    export $(cat jetson_config.env | grep -v '^#' | xargs)
fi

# 示例1：完整部署
echo ""
echo "示例1：完整部署（修改IP、下载文件、拉取代码、运行安装脚本）"
echo "./jetson_deploy.sh 192.168.1.100 192.168.1.101 https://example.com/package.zip https://github.com/user/project.git /home/nvidia/projects/project/install.sh"

# 示例2：跳过IP修改
echo ""
echo "示例2：跳过IP修改"
echo "./jetson_deploy.sh 192.168.1.100 skip https://example.com/package.zip https://github.com/user/project.git /home/nvidia/projects/project/install.sh"

# 示例3：跳过文件下载
echo ""
echo "示例3：跳过文件下载"
echo "./jetson_deploy.sh 192.168.1.100 192.168.1.101 skip https://github.com/user/project.git /home/nvidia/projects/project/install.sh"

# 示例4：仅Git和安装
echo ""
echo "示例4：仅Git克隆和安装"
echo "./jetson_deploy.sh 192.168.1.100 skip skip https://github.com/user/project.git /home/nvidia/projects/project/install.sh"

# 示例5：使用环境变量自定义SSH参数
echo ""
echo "示例5：使用自定义SSH参数"
echo "SSH_USER=myuser SSH_PORT=2222 SSH_KEY=/path/to/key ./jetson_deploy.sh 192.168.1.100 skip skip https://github.com/user/project.git /home/myuser/install.sh"

# 实际执行示例（注释掉，需要时取消注释）
echo ""
echo "========== 执行实际部署 =========="
echo "请根据您的实际情况修改以下参数后执行："

# 取消注释下面的行并修改参数来执行实际部署
# TARGET_IP="192.168.1.100"                    # 目标Jetson设备IP
# NEW_IP="192.168.1.101"                       # 新IP地址（或输入skip跳过）
# DOWNLOAD_URL="https://example.com/file.zip"  # 下载URL（或输入skip跳过）
# GIT_REPO="https://github.com/user/repo.git"  # Git仓库
# INSTALL_SCRIPT="/home/nvidia/install.sh"     # 安装脚本路径

# ./jetson_deploy.sh "$TARGET_IP" "$NEW_IP" "$DOWNLOAD_URL" "$GIT_REPO" "$INSTALL_SCRIPT"

echo ""
echo "注意事项："
echo "1. 确保目标Jetson设备已开启SSH服务"
echo "2. 确保网络连接正常"
echo "3. 如果使用密钥认证，请设置SSH_KEY环境变量"
echo "4. 修改IP地址会导致SSH连接断开，脚本会自动重连"
echo "5. 安装脚本路径应该是目标机器上的绝对路径"