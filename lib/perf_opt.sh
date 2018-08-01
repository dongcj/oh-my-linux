#!/usr/bin/env bash
#
# Author: krrish <krrishdo@gmail.com>
# description: Linux Service config
#

######################################################################
# 作用: 配置 Linux 系统语言
# 用法: Config_Lang
# 注意：
######################################################################
Config_Lang() {

    Log DEBUG "Config language..."
    
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8

    PROFILE_CONF=/etc/profile
    if ! grep -q "LANG=en_US.UTF-8" $PROFILE_CONF; then
        echo "export LANG=en_US.UTF-8" >>$PROFILE_CONF
    fi
    source $PROFILE_CONF
    
    Log DEBUG "Config language successful."
}

######################################################################
# 作用: 配置 SELINUX
# 用法: Config_Selinux
# 注意：
######################################################################
Config_Selinux() {

    Log DEBUG "Config selinux..."
    
    SELINUX_CONF=/etc/selinux/config
    CURRENT_SELINUX_VALUE=`awk -F"=" '/^SELINUX=/ {print $2}' $SELINUX_CONF`
    if [ -f $SELINUX_CONF ]; then
        if [ "$CURRENT_SELINUX_VALUE" != "disabled" ]; then
            sed -i "/^SELINUX=/s/$CURRENT_SELINUX_VALUE/disabled/g" $SELINUX_CONF
        fi
    fi
    setenforce 0 >&/dev/null
    
    Log DEBUG "Config selinux successful."
}


######################################################################
# 作用: 配置 Security
# 用法: Config_Security
# 注意：
######################################################################
Config_Security() {

    Log DEBUG "Config security..."
    
    sed -i s'/Defaults.*requiretty/#Defaults requiretty'/g /etc/sudoers
    
    Log DEBUG "Config security successful."
}

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
# 作用: 配置 Limits
# 用法: Config_Limits
# 注意：
######################################################################
Config_Limits() {

    Log DEBUG "Config limits..."
    
    ulimit -n 655350
    ulimit -u 409600
    
    # seting user profile
    USER_PROFILE=~/.profile
    if ! grep -q "ulimit" $USER_PROFILE; then
        echo "ulimit -n 65535" >>$USER_PROFILE
        echo "ulimit -u 192098" >>$USER_PROFILE
        echo "ulimit -i 192098" >>$USER_PROFILE
    fi
    source $USER_PROFILE

    #/etc/security/limits.conf
    LIMITS_CONF=/etc/security/limits.conf
    grep -q "^[^#].*soft.*nproc" $LIMITS_CONF  || echo "*       soft    nproc   131072" >>$LIMITS_CONF
    grep -q "^[^#].*hard.*nproc" $LIMITS_CONF  || echo "*       hard    nproc   131072" >>$LIMITS_CONF
    grep -q "^[^#].*soft.*nofile" $LIMITS_CONF || echo "*       soft    nofile   655360" >>$LIMITS_CONF
    grep -q "^[^#].*hard.*nofile" $LIMITS_CONF || echo "*       hard    nofile   655360" >>$LIMITS_CONF
    
    if [ -d /etc/security/limits.d ]; then
        echo -e "*\tsoft\tnofile\t655350" > /etc/security/limits.d/90-nproc.conf
        echo -e "*\thard\tnofile\t655350" >> /etc/security/limits.d/90-nproc.conf
    fi
    
    Log DEBUG "Config limits successful."
}

######################################################################
# 作用: 配置 IPv6
# 用法: Config_IPv6
# 注意：
######################################################################
Config_IPv6() {

    Log DEBUG "Config IPv6..."
    
    SYSCTL_CONF=/etc/sysctl.conf
    SYSCONFIG_NETWORK=/etc/sysconfig/network
    
    # one method
    [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && echo 1 >/proc/sys/net/ipv6/conf/all/disable_ipv6
    
    # another method
    if [ "`awk -F"=" '/net.ipv6.conf.all.disable_ipv6/ {print $2}' ${SYSCTL_CONF} | xargs`" != "1" ]; then
        sed -i '/net.ipv6.conf.all.disable_ipv6/d' ${SYSCTL_CONF}
        echo " " >>${SYSCTL_CONF}
        echo "# Disable IPv6 Globally" >>${SYSCTL_CONF}
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >>${SYSCTL_CONF}
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -p >&/dev/null
    fi

    if [ -f $SYSCONFIG_NETWORK ]; then
        if grep -q "NETWORKING_IPV6" $SYSCONFIG_NETWORK; then
            sed -i 's/NETWORKING_IPV6=.*/NETWORKING_IPV6=no/' $SYSCONFIG_NETWORK
        fi
    fi
    
    Log DEBUG "Config ipv6 successful."
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
# 作用: 配置时区
# 用法: Config_Timezone
# 注意：
######################################################################
Config_Timezone() {

    Log DEBUG "Config timezone..."
    
    localtime_file=/etc/localtime
    clock_file=/etc/sysconfig/clock
    if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
        # remove the old localtime file
        rm -rf ${localtime_file}.old && mv ${localtime_file} ${localtime_file}.old
        ln -s /usr/share/zoneinfo/Asia/Shanghai ${localtime_file}

        if [ -f $clock_file ]; then
            sed -i '/^[^#]/d' $clock_file
            echo "ZONE=\"Asia/Shanghai\"" >>$clock_file
            echo "UTC=true" >>$clock_file
        fi
        # update the systime to hardware clock
        hwclock --systohc
    fi
    
    Log DEBUG "Config timezone successful."
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

######################################################################
# 作用: 配置 vim 
# 用法: Config_Vim
# 注意：
######################################################################
Config_Vim() {

    Log DEBUG "Config vim..."

    # vim setting
    if ! grep -q "set paste" /etc/vimrc &>/dev/null; then
        echo "set history=1000" >> /etc/vimrc
        echo "set expandtab" >> /etc/vimrc
        echo "set ai" >> /etc/vimrc
        echo "set tabstop=4" >> /etc/vimrc
        echo "set shiftwidth=4" >> /etc/vimrc
        echo "set paste" >> /etc/vimrc
        echo "colo delek" >> /etc/vimrc
        echo 'syntax on' >> /etc/vimrc
    fi

    # vim as default editor
    if ! grep -q "EDITOR=" $PROFILE_CONF; then
        echo "export EDITOR=vim" >>$PROFILE_CONF
    fi
    
    Log DEBUG "Config vim successful."
}    
    
######################################################################
# 作用: 配置常用命令别名 
# 用法: Config_Alias
# 注意：
######################################################################
Config_Alias() {

    Log DEBUG "Config alias..."
    
    cat <<EOF >~/.bash_aliases
    alias ls='ls --color=always'
    alias dir='dir --color=always'
    alias vdir='vdir --color=always'

    alias grep='grep --color=always'
    alias fgrep='fgrep --color=always'
    alias egrep='egrep --color=always'

    # some more ls aliases
    alias ll='ls -lrt'
    alias vi='vim'
EOF

    PROFILE_CONF=/etc/profile
    if ! grep -q "source ~/.bash_aliases" $PROFILE_CONF; then
        echo "source ~/.bash_aliases" >>$PROFILE_CONF
    fi
    Log DEBUG "Config alias successful."
}


######################################################################
# 作用: 配置常用命令别名 
# 用法: Config_History
# 注意：
######################################################################
Config_History() {

    Log DEBUG "Config history..."
    
    # 1st Method: install bashhub-client, centralize store & search
    # curl -OL https://bashhub.com/setup && bash setup
    
    USER_IP=`who -u am i 2>/dev/null | awk '{print $NF}' | sed -e 's/[()]//g'`
    LOGNAME=`who -u am i | awk '{print $1}'`
    HISTDIR=/usr/local/.history
    
    if [ -z "$USER_IP" ]; then
        USER_IP=`hostname`
    fi

    if [ ! -d "$HISTDIR" ]; then
        mkdir -p $HISTDIR
        chmod 777 $HISTDIR
    fi

    if [ ! -d $HISTDIR/${LOGNAME} ]; then
        mkdir -p $HISTDIR/${LOGNAME}
        chmod 300 $HISTDIR/${LOGNAME}
    fi

    export HISTSIZE=4000

    DT=`date +"%Y%m%d_%H%M%S"`
    export HISTFILE="$HISTDIR/${LOGNAME}/${USER_IP}.history.$DT"
    export HISTTIMEFORMAT="[%Y.%m.%d %H:%M:%S] "
    chmod 600 $HISTDIR/${LOGNAME}/*.history* 2>/dev/null

    # sum function
    if [ -f ~/.bash_profile ]; then
        if ! grep -q "historysum()" ~/.bash_profile; then
            cat <<EOF >>~/.bash_profile
# historysum function add by Krrish

historysum() {

    #history
    printf "\tCOUNT\t\tCOMMAND\n";

    cat ~/.bash_history | awk '{ list[$1]++; } \
    END{
        for(i in list){
            printf("\t%d\t\t%s\n",list[i],i);
        }
    }' | sort -nrk 2 | head

}

EOF
        source ~/.bash_profile
        fi
    fi

# logrotate the history log
cat <<EOF >/etc/logrotate.d/history
${HISTDIR}/* {
    notifempty
    olddir ${HISTDIR}/old
    missingok
    sharedscripts
    copytruncate
}
EOF

    Log DEBUG "Config history successful."
}    

######################################################################
# 作用: 配置邮件 
# 用法: Config_Mail
# 注意：
######################################################################
Config_Mail() {
    
    Log DEBUG "Config mail..."
    
    # resolve postfix error
    postfix_conf=/etc/postfix/main.cf
    if [ -f $postfix_conf ]; then
        # change inet_protocols to ipv4
        sed -i '/^inet_protocols =/s/.*/inet_protocols = ipv4/' $postfix_conf
    fi
    
    # no check mail
    PROFILE_CONF=/etc/profile
    if ! grep -q "unset MAILCHECK" $PROFILE_CONF; then
        echo "unset MAILCHECK" >> $PROFILE_CONF
    fi
    source $PROFILE_CONF

    Log DEBUG "Config mail successful."
}

######################################################################
# 作用: 配置库 
# 用法: Config_Lib
# 注意：
######################################################################
Config_Lib() {

    Log DEBUG "Config library..."
    
    # Append lib
    if ! grep -q "/usr/local/lib" /etc/ld.so.conf; then
        echo "/usr/local/lib/" >> /etc/ld.so.conf
    fi
    
    Log DEBUG "Config library successful."
}

Config_Snippets() {

    Log DEBUG "Config snippets..."
    
    ########### Config snippets ############
    # 将错误按键的beep声关掉。stop the“beep"
    cp -rLfap /etc/inputrc /etc/inputrc.origin
    sed -i '/#set bell-style none/s/#set bell-style none/set bell-style none/' /etc/inputrc

    Log DEBUG "Config snippets successful."
}