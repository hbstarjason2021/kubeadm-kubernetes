#!/usr/bin/env bash

### 安装docker
# 配置yum源
cd /etc/yum.repos.d ; mkdir bak; mv CentOS-Linux-* bak/
# centos7
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
# centos8
# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo

# 安装yum-config-manager配置工具
yum -y install yum-utils
# 设置yum源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# 安装docker-ce版本
yum install -y docker-ce

# 启动并开机自启
systemctl enable --now docker

# Docker镜像源设置
# 修改文件 /etc/docker/daemon.json，没有这个文件就创建
# 添加以下内容后，重启docker服务：
cat >/etc/docker/daemon.json<<EOF
{
   "registry-mirrors": ["http://hub-mirror.c.163.com"],
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
# 重启
systemctl restart docker

# 查看
systemctl status docker containerd
