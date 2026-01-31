#!/bin/bash

set -e

IMAGE_NAME="${1:?Usage: $0 <image_file>}"

virt-customize -a "${IMAGE_NAME}" \
  --smp 2 --memsize 2048 --verbose \
  --timezone "Asia/Hong_Kong" \
  \
  --append-line "/etc/default/grub:# disables OS prober to avoid loopback detection which breaks booting" \
  --append-line "/etc/default/grub:GRUB_DISABLE_OS_PROBER=true" \
  --run-command "update-grub" \
  \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "systemctl enable serial-getty@ttyS1.service" \
  \
  --update \
  --install "sudo,qemu-guest-agent,spice-vdagent,bash-completion,unzip,wget,curl,net-tools,iputils-ping,iputils-arping,iputils-tracepath,vim,zstd,less,mtr-tiny,dnsutils,locales,ncat,ca-certificates,lsof" \
  \
  --run-command "wget -q https://github.com/pouriyajamshidi/tcping/releases/latest/download/tcping-amd64.deb -O /tmp/tcping.deb && apt-get install -y /tmp/tcping.deb && rm -f /tmp/tcping.deb" \
  --run-command "apt-get -y autoremove --purge && apt-get -y clean" \
  \
  --run-command "sed -i 's|Types: deb deb-src|Types: deb|g' /etc/apt/sources.list.d/debian.sources" \
  --run-command "sed -i 's|generate_mirrorlists: true|generate_mirrorlists: false|g' /etc/cloud/cloud.cfg.d/01_debian_cloud.cfg || true" \
  \
  --truncate "/etc/apt/mirrors/debian.list" \
  --append-line "/etc/apt/mirrors/debian.list:https://mirrors.ustc.edu.cn/debian" \
  --truncate "/etc/apt/mirrors/debian-security.list" \
  --append-line "/etc/apt/mirrors/debian-security.list:https://mirrors.ustc.edu.cn/debian-security" \
  \
  --run-command "mkdir -p /etc/systemd/timesyncd.conf.d" \
  --write "/etc/systemd/timesyncd.conf.d/custom-ntp.conf:[Time]
NTP=time.apple.com ntp.aliyun.com ntp.tencent.com" \
  --run-command "systemctl enable systemd-timesyncd" \
  \
  --run-command "sed -i '/^#.*en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen" \
  --run-command "sed -i '/^#.*zh_CN.UTF-8 UTF-8/s/^#//' /etc/locale.gen" \
  --run-command "locale-gen" \
  --write "/etc/default/locale:LANG=en_US.UTF-8" \
  \
  --run-command "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config" \
  \
  --delete "/var/log/*.log" \
  --delete "/var/lib/apt/lists/*" \
  --delete "/var/cache/apt/*" \
  --truncate "/etc/machine-id"
