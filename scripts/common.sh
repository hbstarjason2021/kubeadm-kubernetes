#! /bin/bash


# Variable Declaration
KUBERNETES_VERSION="1.23.3-00"

# disable swap 
sudo swapoff -a
# keeps the swaf off during reboot
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#Letting iptables see bridged traffic 
lsmod | grep br_netfilter
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system


### https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
### mirrors.tuna.tsinghua.edu.cn
### mirrors.aliyun.com
### mirrors.ustc.edu.cn

cp /etc/apt/sources.list /etc/apt/sources.list.bak
##sed -i "s/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g" /etc/apt/sources.list
##sed -i '/^#/d' /etc/apt/sources.list

cat >  /etc/apt/sources.list <<EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-proposed main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ impish-proposed main restricted universe multiverse
EOF


#Clean Install Docker Engine on Ubuntu
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

#Add Docker’s official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg


#### https://download.docker.com/linux/ubuntu
#set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

#Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

#restart containerd
sudo systemctl restart containerd

echo "ContainerD Runtime Configured Successfully"

#Installing kubeadm, kubelet and kubectl
sudo apt-get update -y 
sudo apt-get install -y apt-transport-https ca-certificates curl


## https://mirrors.aliyun.com/kubernetes/apt/
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.ustc.edu.cn/kubernetes/apt kubernetes-xenial main
EOF


<< CONTENT

cat https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

curl -fsSLo apt-key.gpg  https://packages.cloud.google.com/apt/doc/apt-key.gpg
cat apt-key.gpg | sudo apt-key add -

vagrant scp ../apt-key.gpg master:/home/vagrant/


echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
nameserver 223.5.5.5
nameserver 223.6.6.6


#Google Cloud public signing key
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

#Add Kubernetes apt repository
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


#!/usr/bin/env bash

## k8s.gcr.io/kube-apiserver:v1.23.4
## k8s.gcr.io/kube-controller-manager:v1.23.4
## k8s.gcr.io/kube-scheduler:v1.23.4
## k8s.gcr.io/kube-proxy:v1.23.4
## k8s.gcr.io/pause:3.6
## k8s.gcr.io/etcd:3.5.1-0
## k8s.gcr.io/coredns/coredns:v1.8.6

for IT in coredns:v1.8.6 etcd:3.5.1-0 pause:3.6 kube-proxy:v1.23.4 kube-scheduler:v1.23.4 kube-controller-manager:v1.23.4 kube-apiserver:v1.23.4
do
    docker pull "registry.cn-shanghai.aliyuncs.com/XXX/$IT"
    docker tag  "registry.cn-shanghai.aliyuncs.com/XXX/$IT" "k8s.gcr.io/$IT"
    docker rmi  "registry.cn-shanghai.aliyuncs.com/XXX/$IT"
done

exit 0

CONTENT

gpg --keyserver keyserver.ubuntu.com --recv-keys 307EA071
gpg --export --armor 307EA071 | sudo apt-key add -
gpg --keyserver keyserver.ubuntu.com --recv-keys 836F4BEB
gpg --export --armor 836F4BEB | sudo apt-key add -

#Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update -y

sudo apt-get install -y kubelet kubectl kubeadm

sudo apt-mark hold kubelet kubeadm kubectl

