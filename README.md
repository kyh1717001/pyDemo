# Jetson自动化部署脚本

这是一个专为Nvidia Jetson设备设计的自动化部署脚本，能够通过SSH远程执行以下操作：

## 功能特性

1. **SSH连接** - 自动连接到目标Jetson设备
2. **IP地址修改** - 修改目标设备的IP地址（使用netplan）
3. **文件下载** - HTTP下载zip文件并自动解压
4. **Git操作** - 克隆或更新Git仓库
5. **自动安装** - 运行指定的安装脚本

## 文件说明

- `jetson_deploy.sh` - 主部署脚本
- `jetson_config.env` - 配置文件（可选）
- `example_usage.sh` - 使用示例脚本
- `README.md` - 说明文档

## 使用方法

### 基本语法

```bash
./jetson_deploy.sh <目标IP> <新IP地址> <下载URL> <Git仓库URL> <安装脚本路径>
```

### 参数说明

- **目标IP** - Jetson设备当前的IP地址
- **新IP地址** - 要设置的新IP地址（输入'skip'跳过此步骤）
- **下载URL** - 要下载的zip文件URL（输入'skip'跳过此步骤）
- **Git仓库URL** - Git仓库地址
- **安装脚本路径** - 安装脚本在目标机器上的路径

### 使用示例

#### 1. 完整部署
```bash
./jetson_deploy.sh 192.168.1.100 192.168.1.101 https://example.com/package.zip https://github.com/user/project.git /home/nvidia/projects/project/install.sh
```

#### 2. 跳过IP修改
```bash
./jetson_deploy.sh 192.168.1.100 skip https://example.com/package.zip https://github.com/user/project.git /home/nvidia/projects/project/install.sh
```

#### 3. 仅Git和安装
```bash
./jetson_deploy.sh 192.168.1.100 skip skip https://github.com/user/project.git /home/nvidia/projects/project/install.sh
```

#### 4. 使用自定义SSH参数
```bash
SSH_USER=myuser SSH_PORT=2222 SSH_KEY=/path/to/key ./jetson_deploy.sh 192.168.1.100 skip skip https://github.com/user/project.git /home/myuser/install.sh
```

## 环境变量配置

可以通过环境变量或配置文件自定义脚本行为：

```bash
# 加载配置文件
source jetson_config.env

# 或者直接设置环境变量
export SSH_USER=nvidia
export SSH_PORT=22
export SSH_KEY=/path/to/private/key
```

### 支持的环境变量

- `SSH_USER` - SSH用户名（默认：nvidia）
- `SSH_PORT` - SSH端口（默认：22）
- `SSH_KEY` - SSH私钥路径（可选）

## 前置条件

### 本地环境
- Linux系统（支持bash）
- SSH客户端
- 网络连接

### 目标Jetson设备
- 已启用SSH服务
- 网络连接正常
- 具有sudo权限的用户账户
- Ubuntu系统（支持netplan网络配置）

## 工作流程

1. **连接测试** - 验证SSH连接
2. **IP地址修改** - 使用netplan修改网络配置
3. **重新连接** - 使用新IP地址重新建立SSH连接
4. **文件下载** - 下载并解压指定文件
5. **Git操作** - 克隆或更新代码仓库
6. **执行安装** - 运行安装脚本

## 注意事项

1. **SSH认证** - 确保已配置SSH密钥认证或密码认证
2. **网络中断** - 修改IP地址会导致SSH连接暂时中断
3. **权限要求** - 修改网络配置需要sudo权限
4. **备份建议** - 脚本会自动备份网络配置文件
5. **安装脚本** - 安装脚本路径必须是目标机器上的绝对路径

## 错误处理

脚本包含完善的错误处理机制：

- SSH连接失败时提供诊断信息
- 网络配置失败时不影响其他操作
- 文件下载失败时继续执行后续步骤
- Git操作失败时终止执行
- 详细的日志输出便于排查问题

## 日志输出

脚本使用彩色日志输出，便于识别不同类型的信息：

- 🔵 **INFO** - 一般信息
- 🟢 **SUCCESS** - 成功操作
- 🟡 **WARNING** - 警告信息
- 🔴 **ERROR** - 错误信息

## 故障排除

### SSH连接失败
1. 检查目标IP地址是否正确
2. 确认SSH服务是否启动
3. 验证网络连接
4. 检查用户名和密码/密钥

### IP修改失败
1. 确认目标设备使用netplan
2. 检查sudo权限
3. 验证网络接口名称
4. 确认网关地址正确

### 下载失败
1. 检查URL是否有效
2. 验证网络连接
3. 确认目标设备有足够存储空间
4. 检查防火墙设置

### Git操作失败
1. 验证Git仓库URL
2. 检查网络连接
3. 确认访问权限
4. 验证Git是否已安装

## 许可证

此脚本为开源项目，仅供学习和参考使用。