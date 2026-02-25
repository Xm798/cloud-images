# Cloud Images

自定义镜像构建，支持 QEMU/KVM 虚拟机和 LXC 容器。通过 CircleCI 自动构建并上传至 Cloudflare R2。

## VM 镜像 (QEMU/KVM)

基于 Debian 官方 Cloud 镜像，使用 `virt-customize` 定制。

| 文件 | 说明 |
|------|------|
| `debian-13.sh` | 完整版，含开发工具 |
| `debian-13-base.sh` | 基础版，仅网络排查工具 |

### 预装软件

**完整版** (`debian-13.sh`): 基础工具、网络工具 (curl, wget, axel, mtr, dnsutils, ncat, tcping, iperf3, socat)、编辑器 (vim)、压缩工具 (unzip, bzip2, zstd)、开发工具 (build-essential, git)、终端增强 (zsh, tmux, btop)、现代 CLI (fd-find, ripgrep, bat, duf, zoxide, ncdu, tree)、虚拟化 (qemu-guest-agent, spice-vdagent)

**基础版** (`debian-13-base.sh`): 基础工具、网络工具 (curl, wget, mtr, dnsutils, ncat, tcping, net-tools, iputils)、编辑器 (vim)、压缩工具 (unzip, zstd)、虚拟化 (qemu-guest-agent, spice-vdagent)

### 系统配置

- 时区 `Asia/Hong_Kong`，Locale `en_US.UTF-8` + `zh_CN.UTF-8`
- APT 源替换为 USTC 镜像，禁用 deb-src
- NTP 时间同步 (Apple, 阿里云, 腾讯云)
- SSH 禁用密码登录
- 串口 getty、GRUB OS Prober 禁用

### 构建

```bash
apt install libguestfs-tools qemu-utils

wget https://cdimage.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
./debian-13.sh debian-13-genericcloud-amd64.qcow2       # 完整版
./debian-13-base.sh debian-13-genericcloud-amd64.qcow2  # 基础版
```

### Proxmox VE 使用

```bash
TEMPLATE_ID=1000
STORAGE=local

# 创建 VM 并导入磁盘
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

qm importdisk ${TEMPLATE_ID} debian-13-genericcloud-amd64.qcow2 ${STORAGE} -format qcow2
qm set ${TEMPLATE_ID} --scsi0 ${STORAGE}:${TEMPLATE_ID}/vm-${TEMPLATE_ID}-disk-0.qcow2,discard=on,ssd=1
qm set ${TEMPLATE_ID} --boot order=scsi0
qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp
qm template ${TEMPLATE_ID}

# 从模板克隆
qm clone 1000 101 --name "Debian-13-dev" --full 1 --storage apus --format qcow2
qm set 101 --memory 8192 --balloon 2048
qm resize 101 scsi0 256G
```

## LXC 容器

使用 [distrobuilder](https://linuxcontainers.org/distrobuilder/introduction/) 构建 LXC 模板。

| 文件 | 发行版 | 预装软件 |
|------|--------|----------|
| `debian-13-lxc.yaml` | Debian 13 Trixie | vim, zsh, tree, curl, wget, ufw, zstd, zip, unzip, locales, rsync, openssh-server |
| `alpine-lxc.yaml` | Alpine 3.21 | openssh, rsync, vim, zsh, tree, curl, wget, zstd, zip, unzip, tzdata, musl-locales, openrc |

### 系统配置

- 时区 `Asia/Shanghai`，Locale `en_US.UTF-8` + `zh_CN.UTF-8`
- APT/APK 源替换为 USTC 镜像
- SSH MaxAuthTries 15，开机自启
- 登录 Banner 显示 IP 地址

### 构建

```bash
snap install distrobuilder --classic

sudo distrobuilder build-lxc debian-13-lxc.yaml   # 输出 rootfs.tar.xz + meta.tar.xz
sudo distrobuilder build-lxc alpine-lxc.yaml
```

### Proxmox VE 使用

#### Web UI

1. 上传模板：Web UI → 存储 (如 `local`) → CT Templates → Upload，上传 `rootfs.tar.xz`
2. 创建容器：右上角 Create CT，模板选择刚上传的文件，按向导配置

#### CLI

```bash
# 上传 rootfs.tar.xz 到模板存储后创建容器
pct create 200 local:vztmpl/rootfs.tar.xz \
  --hostname my-ct \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --memory 512
```
