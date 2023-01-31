#!/usr/bin/env bash

### 【第一步】修改主机名
# 获取主机名
hostnamectl set-hostname $(grep `hostname -i` /tmp/hosts|awk '{print $2}')


### 【第二步】配置hosts
# 先删除
for line in `cat /tmp/hosts`
do
    sed -i "/$line/d" /etc/hosts
done
# 追加
cat /tmp/hosts >> /etc/hosts


### 【第三步】添加互信
# 先创建秘钥对
ssh-keygen -f ~/.ssh/id_rsa -P '' -q

# 安装expect
yum -y install expect -y

# 批量推送公钥
for line in `cat /tmp/hosts`
do

ip=`echo $line|awk '{print $1}'`
password={{ ansible_ssh_pass }}

expect <<-EOF

spawn ssh-copy-id -i /root/.ssh/id_rsa.pub $ip
expect {
    "(yes/no)?"
    {
        send "yes\n"
        expect "*assword:" { send "$password\n"}
    }
    "*assword:"
    {
        send "$password\n"
    }
}

expect eof
EOF
done


### 【第四步】时间同步
yum install chrony -y
systemctl start chronyd
systemctl enable chronyd
chronyc sources


### 【第五步】关闭防火墙
systemctl stop firewalld
systemctl disable firewalld


### 【第六步】关闭swap
# 临时关闭；关闭swap主要是为了性能考虑
swapoff -a
# 永久关闭
sed -ri 's/.*swap.*/#&/' /etc/fstab


### 【第七步】禁用SELinux
# 临时关闭
setenforce 0
# 永久禁用
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config


### 【第八步】允许 iptables 检查桥接流量
sudo modprobe br_netfilter
lsmod | grep br_netfilter

# 先删
rm -rf /etc/modules-load.d/k8s.conf

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

rm -rf /etc/sysctl.d/k8s.conf
# 设置所需的 sysctl 参数，参数在重新启动后保持不变
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system
