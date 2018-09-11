#!/usr/bin/env bash
#
# Author: krrish <krrishdo@gmail.com>
# description: Linux Service config
#

######################################################################
# 作用: 加快 SSH 访问速度及SSH其它一些相关配置
# 用法: Config_SSH_Server
# 注意：
######################################################################
Config_SSH_Server() {

    Log DEBUG "Config sshd server..."
    
    SSHD_CONF=/etc/ssh/sshd_config;
    sed -i '/UseDNS/s/.*/UseDNS no/' $SSHD_CONF
    # Make ssh faster
    sed -i "/^[[:space:]]*GSSAPIAuthentication/s/.*/GSSAPIAuthentication no/" $SSHD_CONF
    sudo sed -i '/PermitRootLogin prohibit-password/s/.*/PermitRootLogin yes/' $SSHD_CONF

    grep -q "ClientAliveInterval=" $SSHD_CONF || \
      echo ClientAliveInterval=60 >> /etc/ssh/sshd_config
      
    # Use banner
    cat <<EOF >/etc/banner
 * * * * * * * * * * * W A R N I N G * * * * * * * * * * * * *
THIS SYSTEM IS RESTRICTED TO AUTHORIZED USERS FOR AUTHORIZED USE
ONLY. UNAUTHORIZED ACCESS IS STRICTLY PROHIBITED AND MAY BE
PUNISHABLE UNDER THE COMPUTER FRAUD AND ABUSE ACT OF 2013 OR
OTHER APPLICABLE LAWS. IF NOT AUTHORIZED TO ACCESS THIS SYSTEM,
DISCONNECT NOW. BY CONTINUING, YOU CONSENT TO YOUR KEYSTROKES
AND DATA CONTENT BEING MONITORED. ALL PERSONS ARE HEREBY
NOTIFIED THAT THE USE OF THIS SYSTEM CONSTITUTES CONSENT TO
MONITORING AND AUDITING.
EOF
    if ! grep -q Krrish /etc/banner; then
        echo -e "\t\033[1;32mServer Management by Krrish\033[0m" >>/etc/banner
        echo >>/etc/banner
    fi

    # sed -i '/Banner/s/.*/Banner \/etc\/banner/' /etc/ssh/sshd_config

    Log DEBUG "Config ssh server successful."
}



######################################################################
# 作用: 配置 Services
# 用法: Config_Services
# 注意：
######################################################################
Config_Services() {

    Log DEBUG "Config services..."
    
    TO_DISABLE_SERVICE="abrtd acpid atd auditd avahi-daemon autofs bluetooth cpuspeed \
                        cups firstboot hidd ip6tables isdn mcstrans messagebus \
                        NetworkManager nfs-server pcscd rawdevices restorecond \
                        rhnsd rhsmcertd sendmail yum-updatesd"
    
    # disable services
    for i in $TO_DISABLE_SERVICE; do
    
        # start -> stop
        if systemctl -q is-active $i >&/dev/null; then
            Run systemctl stop $i
        fi
        
        # enable -> disable
        if systemctl -q is-enabled $i >&/dev/null; then
            Run systemctl disable $i
        fi
    done
    
    # ubuntu remove mlocate
    dpkg -P mlocate

    # message log warn the follow
    if [ -f /usr/lib/systemd/system/wpa_supplicant.service ]; then
        chmod 644 /usr/lib/systemd/system/wpa_supplicant.service
    fi

    Log DEBUG "Config services successful."
}

######################################################################
# 作用: 优化内核网络参数
# 用法: Config_Kernel_Network
# 注意：
######################################################################
Config_Kernel_Network() {

    Log DEBUG "Config kernel network parameter..."
    
    if ! grep -q "Optimized Networking Globally" ${SYSCTL_CONF}; then
        echo " " >>${SYSCTL_CONF}
        echo "# Optimized Networking Globally" >>${SYSCTL_CONF}

        cat <<EOF >>${SYSCTL_CONF}
fs.file-max = 6815744
fs.aio-max-nr = 1048576
kernel.sem = 250 32000 100 128

# Net tunning
net.core.rmem_default = 254800000
net.core.wmem_default = 254800000
net.core.rmem_max = 254800000
net.core.wmem_max = 254800000
net.core.optmem_max = 25480000

net.core.somaxconn = 32768
net.core.netdev_max_backlog =  250000

net.ipv4.ip_local_port_range = 9000 65500

net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200

net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_rmem = 4096 87380 25480000
net.ipv4.tcp_wmem = 4096 65536 25480000

net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_low_latency = 1

# Memory turnning, /proc/sys/vm/overcommit_memory
vm.overcommit_memory = 1

EOF


# Update sysctl settings
SYST='/sbin/sysctl -e -q -w'
if [ "$(getconf LONG_BIT)" = "64" ]; then
  SHM_MAX=68719476736
  SHM_ALL=4294967296
else
  SHM_MAX=4294967295
  SHM_ALL=268435456
fi
$SYST kernel.msgmnb=65536
$SYST kernel.msgmax=65536
$SYST kernel.shmmax=$SHM_MAX
$SYST kernel.shmall=$SHM_ALL
$SYST net.ipv4.ip_forward=1
$SYST net.ipv4.conf.all.accept_source_route=0
$SYST net.ipv4.conf.all.accept_redirects=0
$SYST net.ipv4.conf.all.send_redirects=0
$SYST net.ipv4.conf.all.rp_filter=0
$SYST net.ipv4.conf.default.accept_source_route=0
$SYST net.ipv4.conf.default.accept_redirects=0
$SYST net.ipv4.conf.default.send_redirects=0
$SYST net.ipv4.conf.default.rp_filter=0
$SYST net.ipv4.conf.eth0.send_redirects=0
$SYST net.ipv4.conf.eth0.rp_filter=0

        sysctl -p >&/dev/null
    fi
    
    Log DEBUG "Config kernel network parameter successful."
}

######################################################################
# 作用: 配置内核参数
# 用法: Config_Kernel
# 注意：
######################################################################
Config_Kernel() {

    Log DEBUG "Config kernel..."
    
    if ! grep -q "Optimized Kernel Globally" ${SYSCTL_CONF}; then
        echo " " >>${SYSCTL_CONF}
        echo "# Optimized Kernel Globally" >>${SYSCTL_CONF}

        cat <<EOF >>${SYSCTL_CONF}
fs.file-max = 6815744
fs.aio-max-nr = 1048576
kernel.sem = 250 32000 100 128

EOF

        sysctl -p >&/dev/null
    fi
    
    Log DEBUG "Config kernel successful."
}

######################################################################
# 作用: 配置本机为 NTP Server
# 用法: Config_NTP_Server
# 注意：
######################################################################
Config_NTP_Server() {

    Log DEBUG "Config ntp server..."
    
    ntp_conf_file=/etc/ntp.conf
    if [ -f $ntp_conf_file ]; then
        if ! grep -q "server * 127.127.1.0" $ntp_conf_file; then
            last_server_no=`sed '/./=' $ntp_conf_file | sed '/./N; s/\n/ /' | grep "^[0-9]* server" | sed -n '$p' | awk '{print $1}'`
            sed -i "${last_server_no}a server 127.127.1.0\nfudge 127.127.1.0 stratum 10" $ntp_conf_file
        fi
    fi

    # auto start ntp server
    Run systemctl enable  ntpd.service
    Run systemctl restart ntpd.service

    Log DEBUG "Config ntp server successful."
}


######################################################################
# 作用: 配置 NTP 客户端
# 用法: Config_NTP_Client
# 注意：
######################################################################
Config_NTP_Client(){
  
    Log DEBUG "Config ntp client..."

    # 
    if ! grep -q "interface ignore wildcard" /etc/ntp.conf; then
        echo "interface ignore wildcard" >> /etc/ntp.conf \
        && systemctl restart ntp && echo "set ntp.conf success"
    fi
    
    Run systemctl stop  ntpd.service
    Run ntpdate $CEPH_AI_VM_HOSTNAME
    Run systemctl start ntpd.service
    
    Log DEBUG "Config ntp client successful."
}



