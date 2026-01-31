# Debian 13 (Trixie) 自定义镜像

用于 Proxmox VE 的 Debian 13 自定义镜像构建工具，支持 QEMU/KVM 虚拟机和 LXC 容器。

## 镜像版本

| 脚本 | 用途 | 输出文件 |
|------|------|----------|
| `debian-13.sh` | 完整版，含开发工具 | `debian-13-genericcloud-amd64-custom.qcow2` |
| `debian-13-base.sh` | 基础版，仅网络排查工具 | `debian-13-base-genericcloud-amd64-custom.qcow2` |

## 功能特性

### 系统配置

- 时区设置为 `Asia/Hong_Kong` (VM) / `Asia/Shanghai` (LXC)
- Locale 支持 `en_US.UTF-8` 和 `zh_CN.UTF-8`
- NTP 时间同步 (阿里云、腾讯云、Apple)
- SSH 安全配置 (禁用密码登录)

### 预装软件 (完整版 debian-13.sh)

| 类别 | 软件包 |
|------|--------|
| 基础工具 | sudo, bash-completion, locales, ca-certificates |
| 网络工具 | curl, wget, axel, net-tools, iputils-ping, mtr-tiny, dnsutils, ncat, tcping |
| 编辑器 | vim, less |
| 压缩工具 | unzip, bzip2, zstd |
| 开发工具 | build-essential, git |
| 终端增强 | zsh, tmux, btop/htop |
| 现代 CLI | fd-find, ripgrep, bat, duf, zoxide, ncdu, tree |
| 虚拟化 | qemu-guest-agent, spice-vdagent |

### 预装软件 (基础版 debian-13-base.sh)

| 类别 | 软件包 |
|------|--------|
| 基础工具 | sudo, bash-completion, locales, ca-certificates |
| 网络工具 | curl, wget, net-tools, iputils-ping/arping/tracepath, mtr-tiny, dnsutils, ncat, tcping |
| 编辑器 | vim, less |
| 压缩工具 | unzip, zstd |
| 系统工具 | lsof |
| 虚拟化 | qemu-guest-agent, spice-vdagent |

### 镜像源优化

- APT 源替换为 USTC 镜像 (mirrors.ustc.edu.cn)
- 禁用 deb-src 源以加速更新

## 前置要求

### QEMU/KVM 虚拟机

```bash
# Debian/Ubuntu
apt install libguestfs-tools

# 下载 Debian Cloud 镜像
wget https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-genericcloud-amd64.qcow2
```

### LXC 容器

```bash
# 安装 distrobuilder
# 参考: https://linuxcontainers.org/distrobuilder/introduction/
snap install distrobuilder --classic
```

## Build

### 构建自定义 VM 镜像

```bash
# 1. 下载官方 Cloud 镜像
wget https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-genericcloud-amd64.qcow2

# 2. 运行自定义脚本 (二选一)
./debian-13.sh debian-13-genericcloud-amd64.qcow2       # 完整版
./debian-13-base.sh debian-13-genericcloud-amd64.qcow2  # 基础版

# 输出: debian-13-genericcloud-amd64.qcow2 (已修改)
```

### 构建 LXC 容器模板

```bash
# 使用 distrobuilder 构建
sudo distrobuilder build-lxc debian-13-lxc.yaml

# 输出: rootfs.tar.xz 和 meta.tar.xz
```

## Usage

### 在 Proxmox VE 中创建 VM 模板

```bash
TEMPLATE_ID=1000
STORAGE=local

# 1. 创建 VM
qm create ${TEMPLATE_ID} \
  --machine q35 \
  --cpu cputype=x86-64-v2-AES \
  --name "debian-13-template" \
  --scsi2 "${STORAGE}:cloudinit" \
  --serial0 socket \
  --vga none \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 \
  --agent 1 \
  --ostype l26 \
  --memory 1024

# 2. 导入磁盘
qm importdisk ${TEMPLATE_ID} debian-13-genericcloud-amd64.qcow2 ${STORAGE} -format qcow2

# 3. 挂载磁盘并配置启动
qm set ${TEMPLATE_ID} --scsi0 ${STORAGE}:${TEMPLATE_ID}/vm-${TEMPLATE_ID}-disk-0.qcow2,discard=on,ssd=1
qm set ${TEMPLATE_ID} --boot order=scsi0
qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp

# 4. 转换为模板
qm template ${TEMPLATE_ID}
```

### 从模板克隆新 VM

```bash
TEMPLATE_ID=1000
VM_ID=101
STORAGE=apus

qm clone ${TEMPLATE_ID} ${VM_ID} \
  --name "Debian-13-dev" \
  --full 1 \
  --storage "${STORAGE}" \
  --format qcow2

qm set ${VM_ID} --memory 8192 --balloon 2048
qm resize ${VM_ID} scsi0 256G
```
