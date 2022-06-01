
########################## 配置节点hosts
cat >>/etc/hosts<<EOF
192.168.10.51 master01
192.168.10.52 master02
192.168.10.53 master03
192.168.10.54 node01
192.168.10.55 node02
EOF

##########################
#关闭防火墙
systemctl disable --now firewalld
#关闭dnsmasq
systemctl disable --now dnsmasq
#关闭postfix
systemctl  disable --now postfix
#关闭NetworkManager
systemctl disable --now NetworkManager
#关闭selinux
sed -ri 's/(^SELINUX=).*/\1disabled/' /etc/selinux/config
setenforce 0
#关闭swap
sed -ri 's@(^.*swap *swap.*0 0$)@#\1@' /etc/fstab
swapoff -a

##########################
#安装ntpdate，需配置yum源
yum install ntpdate -y
#执行同步，可以使用自己的ntp服务器如果没有
ntpdate time2.aliyun.com
#写入定时任务
crontab -e
*/5 * * * * ntpdate time2.aliyun.com
##########################
<< CONTENT

#安装chrony
yum install chrony -y
#在其中一台主机配置为时间服务器
cat /etc/chrony.conf
server time2.aliyun.com iburst   #从哪同步时间
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow 192.168.0.0/16  #允许的ntp客户端网段
local stratum 10
logdir /var/log/chrony
#重启服务
systemctl restart chronyd
#配置其他节点从服务端获取时间进行同步
cat /etc/chrony.conf
server 192.168.10.51 iburst
#重启验证
systemctl restart chronyd
chronyc sources -v
^* master01                      3   6    17     5    -10us[ -109us] +/-   28ms  #这样表示正常

CONTENT
##########################
cat > /etc/security/limits.conf <<EOF
*       soft        core        unlimited
*       hard        core        unlimited
*       soft        nproc       1000000
*       hard        nproc       1000000
*       soft        nofile      1000000
*       hard        nofile      1000000
*       soft        memlock     32000
*       hard        memlock     32000
*       soft        msgqueue    8192000
EOF
##########################
yum install -y sshpass
ssh-keygen -f /root/.ssh/id_rsa -P ''
export IP="192.168.10.51 192.168.10.52 192.168.10.53 192.168.10.54 192.168.10.55"
export SSHPASS=123456
for HOST in $IP;do
     sshpass -e ssh-copy-id -o StrictHostKeyChecking=no $HOST
done
##########################
#升级系统
yum update -y --exclude=kernel*
#升级内核到4.18以上
rpm -ivh kernel-ml-4.20.13-1.el7.elrepo.x86_64.rpm
grub2-set-default 0
grub2-mkconfig -o /boot/grub2/grub.cfg
#修改内核参数
cat >/etc/sysctl.conf<<EOF
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=10
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv4.neigh.default.gc_stale_time=120
net.ipv4.conf.all.rp_filter=0 # 默认为1，系统会严格校验数据包的反向路径，可能导致丢包
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce=2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2
net.ipv4.ip_local_port_range= 45001 65000
net.ipv4.ip_forward=1
net.ipv4.tcp_max_tw_buckets=6000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_synack_retries=2
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.netfilter.nf_conntrack_max=2310720
net.ipv6.neigh.default.gc_thresh1=8192
net.ipv6.neigh.default.gc_thresh2=32768
net.ipv6.neigh.default.gc_thresh3=65536
net.core.netdev_max_backlog=16384 # 每CPU网络设备积压队列长度
net.core.rmem_max = 16777216 # 所有协议类型读写的缓存区大小
net.core.wmem_max = 16777216
net.ipv4.tcp_max_syn_backlog = 8096 # 第一个积压队列长度
net.core.somaxconn = 32768 # 第二个积压队列长度
fs.inotify.max_user_instances=8192 # 表示每一个real user ID可创建的inotify instatnces的数量上限，默认128.
fs.inotify.max_user_watches=524288 # 同一用户同时可以添加的watch数目，默认8192。
fs.file-max=52706963
fs.nr_open=52706963
kernel.pid_max = 4194303
net.bridge.bridge-nf-call-arptables=1
vm.swappiness=0 # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
vm.overcommit_memory=1 # 不检查物理内存是否够用
vm.panic_on_oom=0 # 开启 OOM
vm.max_map_count = 262144
EOF
#加载ipvs模块
cat >/etc/modules-load.d/ipvs.conf <<EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF
systemctl enable --now systemd-modules-load.service
#重启
reboot
#重启服务器执行检查
lsmod | grep -e ip_vs -e nf_conntrack
##########################
mkdir -p /var/log/journal
mkdir -p /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/99-prophet.conf <<EOF
[Journal]
# 持久化保存到磁盘
Storage=persistent
# 压缩历史日志
Compress=yes
SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000
# 最大占用空间 1G
SystemMaxUse=1G
# 单日志文件最大 10M
SystemMaxFileSize=10M
# 日志保存时间 2 周
MaxRetentionSec=2week
# 不将日志转发到 syslog
ForwardToSyslog=no
EOF
systemctl restart systemd-journald && systemctl enable systemd-journald
##########################
##########################
#解压
tar xf nginx.tar.gz -C /usr/bin/
#生成配置文件
mkdir /etc/nginx -p
mkdir /var/log/nginx -p
cat >/etc/nginx/nginx.conf<<EOF 
user root;
worker_processes 1;

error_log  /var/log/nginx/error.log warn;
pid /var/log/nginx/nginx.pid;

events {
    worker_connections  3000;
}

stream {
    upstream apiservers {
        server 192.168.10.51:6443  max_fails=2 fail_timeout=3s;
        server 192.168.10.52:6443  max_fails=2 fail_timeout=3s;
        server 192.168.10.53:6443  max_fails=2 fail_timeout=3s;
    }

    server {
        listen 127.0.0.1:16443;
        proxy_connect_timeout 1s;
        proxy_pass apiservers;
    }
}
EOF
#生成启动文件
cat >/etc/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/usr/bin/nginx -c /etc/nginx/nginx.conf -p /etc/nginx -t
ExecStart=/usr/bin/nginx -c /etc/nginx/nginx.conf -p /etc/nginx
ExecReload=/usr/bin/nginx -c /etc/nginx/nginx.conf -p /etc/nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=15
StartLimitInterval=0
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
#启动
systemctl enable --now nginx.service
#验证
ss -ntl | grep 16443
LISTEN     0      511    127.0.0.1:16443                    *:*

##########################

##########################
