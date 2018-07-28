#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description:
#


######################################################################
# 作用: ping，将每个地址做为一个参数
# 用法: Ping_Test <IP1> <IP2> <IP3> ..
# 注意：
######################################################################
Ping_Test() {

    if [ -z "$ALL_HOST" ]; then
        Log ERROR "Function Test_Ping() error! Usage: Test_Ping <IP1> <IP2> <IP3> ..\n"
    fi

    for i in $ALL_HOST; do
        Log -n DEBUG "pinging $i"
        if ping -c1 -W3 $i >&/dev/null; then
            Log DEBUG "success"
        else
            Log ERROR "failed"
        fi

    done

    Log DEBUG ""
}

######################################################################
# 作用: 自动登陆
# Auto_SSH_Login <IP> <USERNAME> <PASSWORD>
# 注意：
######################################################################
Auto_SSH_Login() {
    if [ "$#" -ne 3 ]; then
        Log ERROR "Function Auto_SSH_Login() error! Usage: Auto_SSH_Login <IP> <USERNAME> <PASSWORD>\n"
    fi

    ip=$1
    username=$2
    password=$3

    expect -c "
    set timeout 10;
    spawn ssh-copy-id $username@$ip
    expect {
        "*yes/no" {send \"yes\r\"; exp_continue}
        "*password:" {send \"$password\r\"; exp_continue}
        "*denied" {send_user \"Password error\"; exit 1}
    }

    "


    #TODO: password wrong do not exit
}




######################################################################
# 作用: 打通给定文件中服务器的通道
# 用法：SSH_Through <HOST_FILE>
# 注意：
######################################################################
SSH_Through() {

    run_file=${RUN_DIR}/${DIALOG_ANS_FILE_FINAL}

    # create directory
    yes | ssh-keygen -t rsa -b 1024 -f /root/.ssh/id_rsa -N "" >/dev/null

    # rm everything, 'known hosts' problem gone :)
    rm -rf ~/.ssh/*

    # copy the key
    cp -rLfap ${LIB_DIR}/sap/configssh/{id_rsa,id_rsa.pub,authorized_keys} ~/.ssh/

    # chmod
    chmod 600 ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/id_rsa.pub
    chmod 400 ~/.ssh/id_rsa
    touch ~/.ssh/known_hosts


    # get the hostname, user, password from hosts.list
    host_info=`INI_Parser $run_file host`

    # TODO: why read line cause the tty not work??
    exec 4<<<"$host_info"
    while read -u4 line; do
        host=`echo $line | awk -F'=' '{print $1}'`
        username=`echo $line | awk -F'|' '{print $((NF-1))}'`
        password=`echo $line | awk -F'|' '{print $((NF))}'`

        Log -n DEBUG "starting Auto_SSH_Login to $host"
        if Auto_SSH_Login $host $username $password >&/dev/null; then
            Log DEBUG "success"

            # private key copy too
            Log -n DEBUG "copying private key..."
            if scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa $username@$host:~/.ssh/ >/dev/null 2>&1; then
                Log DEBUG "success"
            else
                Log ERROR "failed"

            fi
        else
            Log ERROR "failed auto_login_ssh to $host using username=$username, password=$password"
        fi

    done

    Log DEBUG ""
}



######################################################################
# 作用: 将安装目录/文件拷贝至所有指定的服务器
# 用法：SCP_File "<IP1> <IP2> <IP3>" <SOURCE> <DEST>
# 注意：第一次需要用SCP，因为rsync还未安装
# 注意：
######################################################################
SCP_File() {
    if [ "$#" -ne 3 ]; then
        Log ERROR "Function SCP_File() error! Usage: SCP_File <IPLIST> > <SOURCE> <DEST>\n"
    fi
    all_server=$1
    source=$2
    dest=$3

    for i in $all_server; do
        Log -n DEBUG "scp file \"$source\" to \"$i:$dest\""
        if scp -o StrictHostKeyChecking=no -r ${source} $i:${dest} >/dev/null 2>&1; then
            Log DEBUG "success"
        else
            Log ERROR "failed"
        fi
    done

    Log DEBUG ""

}

######################################################################
# 作用: 将安装目录拷贝至所有指定的服务器
# 用法：Rsync_File "<IP1> <IP2> <IP3>" <SOURCE> <DEST>
# 注意：
######################################################################
Rsync_File() {
    if [ "$#" -ne 3 ]; then
        Log ERROR "Function Rsync_File() error! Usage: Rsync_File <IPLIST> <SOURCE> <DEST>\n"
    fi
    all_server=$1
    source=$2
    dest=$3

    for i in $all_server; do

        [ ${#source} > 30 ] && source_alias=$(basename $source)
        [ ${#dest} > 30 ] && dest_alias=$(basename $dest)
        Log -n DEBUG "rsync file \"$source_alias\" to \"$i:$dest_alias\""
        if rsync -ar ${source} $i:${dest} --exclude-from=${CONF_DIR}/exclude_rsync.list >/dev/null 2>&1; then
            Log DEBUG "success"
        else
            Log ERROR "failed"
        fi
    done
    Log DEBUG ""
}


######################################################################
# 作用: 将当前运行机器上的 文件/消息/函数 回推给installer,
# 用法: Pusher <TYPE> <FILE_OR_MSG_OR_FUN>
# 注意：TYPE: FILE / MSG / FUNCTION;
# ++ 文件会推送至ceph-ai上相同的目录, 但是后缀名会加上.$(hostname -s)
######################################################################
Pusher() {
    if [ $# -ne 2 ];then
        Log ERROR "Function Pusher() error! Usage: Pusher <TYPE> <FILE_OR_MSG_OR_FUN>\n"
    fi

    type=$1
    object=$2

    case $type in

        FILE)
        # use scp to copy
        Log DEBUG "pusher $type $object with the follow scp command..."
        Run SCP_File $CEPH_AI_VM_HOSTNAME $object ${object}.${MY_HOSTNAME}
        ;;

        MSG)

        ;;

        FUNCTION)

        ;;

        *) Log ERROR "Function Pusher() error! Usage: Pusher <TYPE> <FILE_OR_MSG_OR_FUN>\n"
        ;;

    esac

}

######################################################################
# 作用: 处理推送过来的 文件/消息/函数
# 如果是FILE, installer用logtail处理;
# 如果是MSG, 接收
# 如果是函数,
# 用法: Push_MSG <LOCAL_FILE | MSG> [DST_FILE]
# 注意：
######################################################################
Puller() {

    :



}





######################################################################
# 作用: 在远程机器上执行指定的命令
# 用法: Remote_Exec <HOST> <COMMAND> [TIMEOUT]
# 注意：
######################################################################
Remote_Exec() {
    if [ "$#" -lt 2 ]; then
        Log ERROR "Function Usage：Remote_Exec <HOSTLIST> <COMMAND> [TIMEOUT]\n"
    fi


    # 分隔符有可能是"|"或 ","
    hostlist=`echo "$1" | tr ',|' ' ' | xargs`
    command="$2"
    command_short=`echo $command | sed "s#/root/Ceph_AI/bin/install -F ##"`
    timeout=${3:-0}

    Checker is_allnum $timeout || Log ERROR "TIMEOUT should be NUMBERS"

    # if use pdsh, translate separate to dot
    # hostlist=${hostlist// /,}

    # use pdsh to run the command
    if [ "$timeout" -eq 0 ]; then
        Log -n DEBUG "Remote_Exec [ $command_short ] on selected host"
    else
        Log -n DEBUG "Remote_Exec [ $command_short ] on selected host; timeout=$timeout"
    fi

    #[[ Is_TTY ]] && stty -ixon

    # run command using pdsh
    #ret_content=`/usr/bin/pdsh -w $hostlist -t $timeout -u $timeout -S "$command"`

    # see more detail

    #Log DEBUG "/usr/bin/pssh -H \"$hostlist\" -p 8 -t $timeout \"$command\""



    # run command using pssh, -p means max number of parallel threads
    ret_content=`/usr/bin/pssh -H "$hostlist" -p 8 -t $timeout "$command"`
    retcode=$?

    err_host=`echo "${ret_content}" | egrep "FAILURE"\
            | awk '{print $4}' | sort | uniq | xargs`
    suc_host=`echo "${ret_content}" | egrep "SUCCESS"\
            | awk '{print $4}' | sort | uniq | xargs`

    suc_content=`echo "$ret_content" | grep "SUCCESS"`
    err_content=`echo "$ret_content" | grep "FAILURE"`

    if [ $retcode -eq 0 ]; then
        # 如果返回结果中有FAILURE
        if echo "${ret_content}" | egrep -q "FAILURE"; then
            if [ -n "$suc_content" ]; then
                Log DEBUG "SUCC run on host: $suc_host"
            fi
            Log ERROR "ERROR run on host: ${BOLD}$err_host${NORMAL}\n`echo "$err_content" | sed 's/^/  /'`"
            return 1
        else
            Log DEBUG "success"
            Log DEBUG ""
            return 0
        fi
    else
        if [ -n "$suc_content" ]; then
            Log DEBUG "SUCC run on host: $suc_host"
        fi
        Log ERROR "ERROR run on host: ${BOLD}$err_host${NORMAL}\n`echo "$err_content" | sed 's/^/  /'`"
        return 2
    fi


}


######################################################################
# 作用: 更新自己手工建立的 repo metadata
# 用法: Update_RepoData </RPM/PATH/>
# 注意：
######################################################################
Update_RepoData() {

    yum_root="/var/www/html/Krrish-Repo"

    # create repo
    arch_arr='x86_64 noarch dep'

    for arch in $arch_arr; do
        Log -n DEBUG "creating $arch repo"
        if createrepo -d -p --update -s sha $yum_root/$arch >/dev/null; then 
            Log DEBUG "success"
        else
            Log ERROR "failed"
        fi
    done
    
    Log DEBUG ""

}

######################################################################
# 作用: 设置基础 repo
# 用法: Prepare_Repo
# 注意：需要与 Update_RepoData 配合使用
######################################################################
Prepare_Repo() {

    Log DEBUG "preparing yum repo..."
    # install the ceph key
    Run rpm --import http://${CEPH_AI_VM_NAME}/Ceph-AI-Packages/base-release.asc
    Run rpm --import http://${CEPH_AI_VM_NAME}/Ceph-AI-Packages/ceph-release.asc
    Run rpm --import http://${CEPH_AI_VM_NAME}/Ceph-AI-Packages/dep-release.asc
    
    # backup the repo
    mkdir -p /etc/yum.repos.d/bak/
    find /etc/yum.repos.d/ -maxdepth 1 -type f -not -name 'Ceph-AI.repo' -exec mv {} /etc/yum.repos.d/bak/ \;

    # config the yum.conf
    sed -i 's/bugtracker_url=.*/bugtracker_url=http://${REPORT_SERVER}/rpmbug' /etc/yum.conf
    
    # get the latest repo
    Log DEBUG "get Ceph_AI.repo to /etc/yum.repos.d/"
    Conf_Replacer ${CONF_DIR}/Ceph_AI.repo.conf  /etc/yum.repos.d/Ceph_AI.repo  CEPH_AI_VM_HOSTNAME
    
    # DO NOT use, because the wget is not install now
    #Run wget -N -P /etc/yum.repos.d/ http://${CEPH_AI_VM_NAME}/Ceph-AI-Packages/Ceph-AI.repo
    
    Run yum clean all
    yum --disablerepo=\* --enablerepo=DVD-HTTP,local_ceph,local_ceph-noarch local_dep makecache
    Log SUCC "prepare yum repo successful."
}


######################################################################
# 作用: 为服务器安装所需要的基础软件
# 用法: Install_Basic_Soft
# 注意：依赖 Check_OS_DISTRIB
######################################################################
Install_Basic_Soft() {

    Log DEBUG "${COLOR_YELLOW}Installing basic software...${COLOR_CLOSE}"
    
    softlist="bash-completion rsync  python-pip ipmitool \
    net-tools  pciutils iotop mycli ifstat locales bmon \
    lsscsi  smartmontools htop ntp  fio bc nmon wget "
    softlist=`echo $softlist`

    # add chkconfig for ubuntu
    if [ "$OS" = "Ubuntu" ]; then
    
        # prepare the apt
        dpkg --configure -a
        apt autoremove
        
        which chkconfig || { rm -rf /usr/bin/chkconfig && \
        Run $PKG_INST_CMD sysv-rc-conf rcconf && \
        ln -s /usr/sbin/sysv-rc-conf /usr/bin/chkconfig; }
    fi
    
    Run $PKG_INST_CMD $softlist
    
    # if the has pci raid
    pci_info=`lspci`
    if echo "$pci_info" | grep -i raid | grep -iq mega; then
        Run yum -y -q install MegaCli

    elif echo "$pci_info" | grep -i raid | grep -iq hewlett; then
        Run yum -y -q install hpacucli
    fi
    
    Log SUCC "Install basic software successful."
}



######################################################################
# 作用: 配置本机为NTP Server
# 用法: Config_NTP_Server
# 注意：
######################################################################
Config_NTP_Server() {

    Log -n DEBUG "Config ntp server"
    
    ntp_conf_file=/etc/ntp.conf
    if [ -f $ntp_conf_file ]; then
        if ! grep -q "server * 127.127.1.0" $ntp_conf_file; then
            last_server_no=`sed '/./=' $ntp_conf_file | sed '/./N; s/\n/ /' | grep "^[0-9]* server" | sed -n '$p' | awk '{print $1}'`
            sed -i "${last_server_no}a server 127.127.1.0\nfudge 127.127.1.0 stratum 10" $ntp_conf_file
        fi
    fi
    Log DEBUG "ok"

    # auto start ntp server
    Run systemctl enable  ntpd.service
    Run systemctl restart ntpd.service

    Log DEBUG ""
}




######################################################################
# 作用: 设置本机Hosts
# 用法: Config_NTP_Server
# 注意：
######################################################################
Gen_Hosts_File() {

    hosts_tmpfile=${TMP_DIR}/${HOSTS_TMP_FILE}

    Log -n DEBUG "generate hosts file in $hosts_tmpfile"

    # write localhost domain
    cat <<EOF >$hosts_tmpfile
# local doamin support
127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
::1             localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF

    # write ceph-ai
    cat <<EOF >>$hosts_tmpfile
# ceph installer
$CEPH_AI_IP     $CEPH_AI_VM_HOSTNAME   ${CEPH_AI_VM_HOSTNAME}.$FULL_DOMAIN

# hosts auto generate by Ceph_AI
EOF

    # write ceph hosts
    for line in $HOST_CONTENT; do
        ip_addr=`echo $line | awk -F'=' '{print $2}' | awk -F'|' '{print $2}' | awk -F',' '{print $1}'`
        this_hostname=`echo $line | awk -F'=' '{print $1}'`
        cat <<EOF >>$hosts_tmpfile
$ip_addr    $this_hostname   ${this_hostname}.$FULL_DOMAIN
EOF
    done

    Log DEBUG "success"

}


######################################################################
# 作用: 设置 Hosts 文件和 hostname
# 用法: Set_Hosts_Hostname
# 注意：
######################################################################
Set_Hosts_Hostname() {

    hosts_tmpfile=${TMP_DIR}/${HOSTS_TMP_FILE}
    hosts_file=/etc/hosts
    hostname_file=/etc/hostname

    Log -n DEBUG "apply hosts file from $hosts_tmpfile"

    # backup the old hosts file
    #mkdir -p ${TMP_DIR}/hosts-bak
    #cp -rLfap $hosts_file ${TMP_DIR}/hosts-bak/hosts-`$NOW_TIME_PATH`

    # write the new hosts file
    cat ${hosts_tmpfile} >$hosts_file

    Log DEBUG "success"


    Log -n DEBUG "set hostname for $MY_IP"
    my_hostname=`grep -w $MY_IP $hosts_file | awk '{print $3}'`

    hostname $my_hostname
    echo $my_hostname >$hostname_file

    # export hostname
    MY_HOSTNAME=`hostname -s`
    export MY_HOSTNAME

    Log DEBUG "success"
    Log DEBUG ""
}




######################################################################
# 作用: 加快 SSH 访问速度及SSH其它一些相关配置
# 用法: Config_SSH_Server
# 注意：
######################################################################
Config_SSH_Server() {
    Log -n DEBUG "Configing ssh server..."

    ############# Config SSH ###############
    ########################################
    ## Config the SSHD Service
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

    Log SUCC "Config ssh server successful."
}





######################################################################
# 作用: 检查服务器的网络接口
# 用法: Check_Network
# 注意：
######################################################################
Network_CheckDevice() {

:<<EOF
    NETWORK_PCIETHER_COUNT=4
    NETWORK_PCIETHER_1G_COUNT=2
    NETWORK_PCIETHER_1G_BRAND="Intel Corporation I350 Gigabit (rev 01)"
    NETWORK_PCIETHER_10G_COUNT=2
    NETWORK_PCIETHER_10G_BRAND="Intel Corporation 82599ES 10-Gigabit SFI/SFP+ (rev 01)"
    NETWORK_ALLETHERS="enp2s0f0 enp2s0f1 enp129s0f0 enp129s0f1"
    NETWORK_PHYETHERS="enp2s0f0 enp2s0f1 enp129s0f0 enp129s0f1"
    NETWORK_PHYETHERS_INFO="enp2s0f0,00:25:90:ec:5c:fe,1000Mb/s,yes enp2s0f1,00:25:90:ec:5c:ff,1000baseT,no enp129s0f0,00:1b:21:bb:ce:bc,10000baseT,no enp129s0f1,00:1b:21:bb:ce:be,10000Mb/s,yes"
    NETWORK_IPADDR="192.168.120.244"
    NETWORK_IPMASK="255.255.255.0"
    NETWORK_GATEWAY="192.168.120.1"
    NETWORK_DNS="8.8.8.8"
    NETWORK_DOMAIN="asdaf.cxx"

EOF

    # func in func, fuck
    get_network_info() {


        # get the networkinfo
        if [ -f "$1" ]; then
            NETWORK_PHYETHERS_INFO=`INI_Parser $1 network NETWORK_PHYETHERS_INFO`
            NETWORK_PHYETHERS=`INI_Parser $1 network NETWORK_PHYETHERS`
            NET_USE_ETHER_TYPE=`INI_Parser $1 network NET_USE_ETHER_TYPE`
        fi

        # calc the actived ethernet
        NETWORK_PHYETHERS_1G=`echo $NETWORK_PHYETHERS_INFO | xargs -n1 |grep "10\{1,3\}[Mb]" | awk -F',' '{print $1}'`
        NETWORK_PHYETHERS_10G=`echo $NETWORK_PHYETHERS_INFO | xargs -n1 | grep "10\{4,9\}[Mb]" | awk -F',' '{print $1}'`

        # calc the actived ethernet count
        NETWORK_PHYETHERS_1G_COUNT=`echo $NETWORK_PHYETHERS_1G | wc -w`
        NETWORK_PHYETHERS_10G_COUNT=`echo $NETWORK_PHYETHERS_10G | wc -w`



        # calc the actived ethernet
        NETWORK_PHYETHERS_1G_ACTIVE=`echo $NETWORK_PHYETHERS_INFO | xargs -n1 | grep "10\{1,3\}[Mb]" | grep yes | awk -F',' '{print $1}'`
        NETWORK_PHYETHERS_10G_ACTIVE=`echo $NETWORK_PHYETHERS_INFO | xargs -n1 | grep "10\{4,9\}[Mb]" | grep yes | awk -F',' '{print $1}'`

        # calc the actived ethernet count
        NETWORK_PHYETHERS_1G_ACTIVE_COUNT=`echo $NETWORK_PHYETHERS_1G_ACTIVE | wc -w`
        NETWORK_PHYETHERS_10G_ACTIVE_COUNT=`echo $NETWORK_PHYETHERS_10G_ACTIVE | wc -w`



        # at least two ethernet(at least 1000M required & linked)
        total_ethernet=$(($NETWORK_PCIETHER_1G_COUNT + $NETWORK_PCIETHER_10G_COUNT))
        total_effective_ethernet=$(($NETWORK_PCIETHER_1G_ACTIVE_COUNT + $NETWORK_PCIETHER_10G_ACTIVE_COUNT))

    }



    # other host need to be check later
    for i in $OSD_HOST; do


        # get from last hostinfo file
        get_network_info ${RUN_DIR}/${HOSTINFO_FILE}.$i


        ### CHECK LOGICAL START

        # error if less than 2 1G pci network
        [ $total_ethernet -lt 2 ] && Log ERROR "at least 2 1G network cards are required"


        ## get public network ethernet

        # if my pub ether is not raw ethernet
        if [ $NET_USE_ETHER_TYPE = "raw" ]; then
            need_bond_pub=true
            master_ether_pub=$NET_USE_ETHER

            # if my pub ether use 1G link
            if echo "$NETWORK_PHYETHERS_1G_ACTIVE" | grep -q $NET_USE_ETHER; then

                # first, linked 1G; then unlinked 1G
                assume_slave_ether_pub=`echo "$NETWORK_PHYETHERS_1G_ACTIVE" | grep -vw "$NET_USE_ETHER" | sed -n '1p'`

                if [ -z "$assume_slave_ether_pub" ]; then
                    assume_slave_ether_pub=`echo "$NETWORK_PHYETHERS_1G" | grep -vw "$NET_USE_ETHER" | sed -n '1p'`
                fi

                if [ -z "$assume_slave_ether_pub" ]; then
                    single_bond_pub=true
                else
                    slave_ether_pub=$assume_slave_ether_pub
                    single_bond_pub=false
                fi


            else

                Log ERROR "currently now my public ether only support 1G ether network"

            fi


        ########### TODO
        # not in
        else
            need_bond_pub=false
            Log WARN "found my public ether type: $NET_USE_ETHER_TYPE, skip bond0 on $i"
            continue
        fi


        # if has 10G network card
        if [ $NETWORK_PCIETHER_10G_COUNT -ge 1 ]; then

            # if no active
            while [ $NETWORK_PCIETHER_10G_ACTIVE_COUNT -eq 0 ]; do

                unlinked_ether_10G=`echo $NETWORK_PHYETHERS_10G`

                Log -n DEBUG "at least one 10G link of $unlinked_ether_10G on host $i is required, waiting.."

                sleep 30

                # re-check & re-set the network variable
                eval `ssh -q sc1r01n01 "/root/Ceph_AI/bin/install -F 'Get_NetInfo'" 2>/dev/null | grep -v "adding" | awk -F'--' '{print $2}'`


                #  re-get the network info
                get_network_info


            done
            Log DEBUG "done"

            # get the first linked 10G as bond master ether
            master_ether_clu=`echo "$NETWORK_PCIETHER_10G_ACTIVE" | sed -n '1p'`

            # if more than one 10G pci ethernet
            #if
            assume_ether_10G_active=`echo "$NETWORK_PCIETHER_10G_ACTIVE" | sed -n '2p'`
            #second_ether_10G_no_master

        # no 10G card
        else

            :


        fi


    done
}



######################################################################
# 作用: 修改服务器网卡名称, 上联网络按eth命名, 下联网络按clu命名
# 用法: Network_RenameDevice
# 注意：
######################################################################
Network_RenameDevice() {

    NETWORK_PHYETHERS_INFO=

    :


}



######################################################################
# 作用: 网卡绑定
# 用法: Network_BondingDevice
# 注意：
######################################################################
Network_BondingDevice() {

    :

}




######################################################################
# 作用: Check/Rename/Bonding Device
# 用法: Network_ChangeDevice
# 注意：
######################################################################
Network_ChangeDevice() {





    :




}




######################################################################
# 作用: 配置Linux系统
# 用法: Config_System
# 注意：
######################################################################
Config_System() {


    ############ Config LANG ###############
    ########################################
    Log DEBUG "Config Language..."
    apt-get install -y wget locales
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8

    PROFILE_CONF=/etc/profile
    if ! grep -q "LANG=en_US.UTF-8" $PROFILE_CONF; then
        echo "export LANG=en_US.UTF-8" >>$PROFILE_CONF
    fi
    source $PROFILE_CONF
    Log DEBUG "config ok"

    ############ Config Selinux ############
    ########################################
    Log DEBUG "Config Selinux..."
    SELINUX_CONF=/etc/selinux/config
    CURRENT_SELINUX_VALUE=`awk -F"=" '/^SELINUX=/ {print $2}' $SELINUX_CONF`
    if [ -f $SELINUX_CONF ]; then
        if [ "$CURRENT_SELINUX_VALUE" != "disabled" ]; then
            sed -i "/^SELINUX=/s/$CURRENT_SELINUX_VALUE/disabled/g" $SELINUX_CONF
        fi
    fi
    setenforce 0 >&/dev/null
    Log DEBUG "config ok"



    ########## Config Security #############
    ########################################
    Log DEBUG "Config Security..."
    sed -i s'/Defaults.*requiretty/#Defaults requiretty'/g /etc/sudoers
    Log DEBUG "Config ok"


    ########## Config Services #############
    ########################################
    Log DEBUG "Config Services..."
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

    Log DEBUG "Config ok"


    ########### Config Limits ##############
    ########################################
    Log DEBUG "Config Limits..."
    
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
    
    
    
    Log DEBUG "Config ok"



    ############# Config IPv6 ##############
    ########################################
    Log DEBUG "Config IPV6..."
    
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
    Log DEBUG "disabled ok"


    ######### Optimized Networking #########
    ########################################
    Log DEBUG "Optimizing Networking..."
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
    Log DEBUG "Optimized ok"


    ######### Optimized Kernel #############
    ########################################
    Log DEBUG "Optimizing Kernel..."
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
    Log DEBUG "Optimized ok"

    
    ########## Config TimeZone #############
    ########################################
    Log DEBUG "Config TIMEZONE..."
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
    Log DEBUG "Config ok"


    ########## client NTP client ###########
    ########################################
    Log DEBUG "Config ntp client..."
    ntp_conf_file=/etc/ntp.conf

    # 
    if ! grep -q "interface ignore wildcard" /etc/ntp.conf; then
        echo "interface ignore wildcard" >> /etc/ntp.conf \
        && systemctl restart ntp && echo "set ntp.conf success"
    fi
    
    Run systemctl stop  ntpd.service
    Run ntpdate $CEPH_AI_VM_HOSTNAME
    Run systemctl start ntpd.service
    Log DEBUG "Config ok"




    ########### Config vim #################
    ########################################
    Log DEBUG "Config vim..."
    if [ -f /root/.bashrc ]; then
        if which vim >/dev/null 2>&1; then
            grep -q 'alias vi=' ~/.bashrc || \
            { sed -i "s@alias mv=\(.*\)@alias mv=\1\nalias vi=vim@" ~/.bashrc && \
            echo 'syntax on' >> /etc/vimrc; }
        fi
    fi

    # vim setting
    if ! grep -q "set paste" /etc/vimrc &>/dev/null; then
        echo "set history=1000" >> /etc/vimrc
        echo "set expandtab" >> /etc/vimrc
        echo "set ai" >> /etc/vimrc
        echo "set tabstop=4" >> /etc/vimrc
        echo "set shiftwidth=4" >> /etc/vimrc
        echo "set paste" >> /etc/vimrc
        echo "colo delek" >> /etc/vimrc
    fi

    # vim as default editor
    if ! grep -q "EDITOR=" $PROFILE_CONF; then
        echo "export EDITOR=vim" >>$PROFILE_CONF
    fi

    ########### Config alias ###############
    ########################################
    Log DEBUG "Config alias..."
    
    cat <<EOF >~/.bash_aliases
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'

    # some more ls aliases
    alias ll='ls -lrt'
EOF

    PROFILE_CONF=/etc/profile
    if ! grep -q "source ~/.bash_aliases" $PROFILE_CONF; then
        echo "source ~/.bash_aliases" >>$PROFILE_CONF
    fi
    Log DEBUG "Config ok"

    ######### Config history ###############
    ########################################
    Log DEBUG "Config history..."
    
    # 1st Method: install bashhub-client, centralize store & search
    curl -OL https://bashhub.com/setup && bash setup
    
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

    Log DEBUG "Config ok"
    
    ########### Config Postfix #############
    ########################################
    
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
    
    # Append lib
    if ! grep -q "/usr/local/lib" /etc/ld.so.conf; then
        echo "/usr/local/lib/" >> /etc/ld.so.conf
    fi
    
    ########### Config snippets ############
    # 将错误按键的beep声关掉。stop the“beep"
    cp -rLfap /etc/inputrc /etc/inputrc.origin
    sed -i '/#set bell-style none/s/#set bell-style none/set bell-style none/' /etc/inputrc

}




######################################################################
# 作用: 获取服务器 System 信息
# 用法: Get_SystemInfo
# 注意：
######################################################################
Get_SystemInfo() {

    Log DEBUG "${COLOR_YELLOW}Getting system info...${COLOR_CLOSE}"
    DMIDECODE=`dmidecode -t system`
    SYSTEM_MANUFACTURER=`echo "$DMIDECODE" | grep 'Manufacturer' | head -n 1 | cut -f 2 -d':' | xargs`
    SYSTEM_PRODUCTNAME=`echo "$DMIDECODE" | grep 'Product Name' | head -n 1 | cut -f 2 -d':' | xargs`
    SYSTEM_SERIALNUMBER=`echo "$DMIDECODE" | grep 'Serial Number' | head -n 1 | cut -f 2 -d':' | xargs`
    SYSTEM_UUID=`echo "$DMIDECODE" | grep 'UUID' | head -n 1 | cut -f 2 -d':' | xargs`

    Log DEBUG " --SYSTEM_MANUFACTURER=\"$SYSTEM_MANUFACTURER\""
    Log DEBUG " --SYSTEM_PRODUCTNAME=\"$SYSTEM_PRODUCTNAME\""
    Log DEBUG " --SYSTEM_SERIALNUMBER=$SYSTEM_SERIALNUMBER"
    Log DEBUG " --SYSTEM_UUID=$SYSTEM_UUID"
    
    Log SUCC "Get system info successful."
}


######################################################################
# 作用: 获取服务器 OS 信息
# 用法: Get_OSInfo
# 注意：
######################################################################
Get_OSInfo() {

    Log DEBUG "${COLOR_YELLOW}Getting OS info...${COLOR_CLOSE}"

    OS_DISTRIBUTION=${OS}
    OS_FAMILY=`uname`
    [ "$OS_FAMILY" != "Linux" ] && { Log ERROR "Not Linux? exit"; return 1; }
    OS_VERSION=`cat $RELEASE_FILE | grep ${OS} | sed -n '$p'  | awk '{print $((NF-1))}'`
    OS_ARCH=`arch`;OS_BIT=`getconf LONG_BIT`
    OS_HOSTID=`hostid`
    OS_HOSTNAME=${MY_HOSTNAME}

    Log DEBUG " --OS_DISTRIBUTION=\"$OS_DISTRIBUTION\""
    Log DEBUG " --OS_FAMILY=$OS_FAMILY"
    Log DEBUG " --OS_VERSION=$OS_VERSION"
    Log DEBUG " --OS_ARCH=$OS_ARCH"
    Log DEBUG " --OS_HOSTID=$OS_HOSTID"
    Log DEBUG " --OS_HOSTNAME=$OS_HOSTNAME"
    
    Log SUCC "Get OS info successful."

}



######################################################################
# 作用: 获取服务器 CPU 信息
# 用法: Get_CPUInfo
# 注意：
######################################################################
Get_CPUInfo() {

    Log DEBUG "${COLOR_YELLOW}Getting CPU info...${COLOR_CLOSE}"
    
    CPU_THREAD=`egrep -c 'processor([[:space:]]+):.*' /proc/cpuinfo`
    CPU_PHYSICAL=`grep "physical id" /proc/cpuinfo | sort | uniq | wc -l`
    # if cpu has HT, one core has more than 2 (inclue 2) threads;
    CPU_IFHT=`if [ $(grep "core id" /proc/cpuinfo | grep -w 0 | wc -l) -ge 2 ]; then echo 1; else echo 0;fi`
    CPU_CORE=`if [ "$CPU_IFHT" -eq 1 ];then printf "%d" $((CPU_THREAD/2));else echo $CPU_THREAD;fi`
    CPU_SPEED=`grep 'cpu MHz' /proc/cpuinfo | sort | sed -n '$p' | awk '{printf "%d", $NF}'`
    CPU_FAMILY=`if grep AuthenticAMD /proc/cpuinfo >/dev/null; then echo AMD; elif grep \
                Intel /proc/cpuinfo >/dev/null; then echo Intel; else echo unknown; fi`
    CPU_MODELNAME=`grep "model name" /proc/cpuinfo | uniq | awk -F":" '{print $2}' | sed 's/           / /' | xargs`

    Log DEBUG " --CPU_THREAD=$CPU_THREAD"
    Log DEBUG " --CPU_PHYSICAL=$CPU_PHYSICAL"
    Log DEBUG " --CPU_IFHT=$CPU_IFHT"
    Log DEBUG " --CPU_CORE=$CPU_CORE"
    Log DEBUG " --CPU_SPEED=$CPU_SPEED"
    Log DEBUG " --CPU_FAMILY=$CPU_FAMILY"
    Log DEBUG " --CPU_MODELNAME=\"$CPU_MODELNAME\""
    
    Log SUCC "Get CPU info successful."
}




######################################################################
# 作用: 获取服务器 Memory 信息
# 用法: Get_MEMInfo
# 注意：
######################################################################
Get_MEMInfo() {

    Log DEBUG "${COLOR_YELLOW}Getting Memory info...${COLOR_CLOSE}"
    
    MEM_INFO=`cat /proc/meminfo`
    _MEMORY_TOTAL=`echo "$MEM_INFO" | grep MemTotal | awk  '{print $2}'`
    MEMORY_TOTAL=`printf "%G" $(echo "scale = 0; $_MEMORY_TOTAL/1024/1002" | bc)`
    _MEMORY_FREE=`echo "$MEM_INFO" | grep MemFree | awk  '{print $2}'`
    MEMORY_FREE=`printf "%G" $(echo "scale = 0; $_MEMORY_FREE/1024/1002" | bc)`
    MEMORY_INFO=`dmidecode --type 17 | grep Speed`
    MEMORY_SLOT=`echo "$MEMORY_INFO" | wc -l`
    MEMORY_NUMBER=`echo "$MEMORY_INFO" | grep MHz | wc -l`
    # memory speed maybe
    MEMORY_SPEED=`echo "$MEMORY_INFO" | grep MHz |  sed -n 's/.*Speed: \(.*\) MHz/\1/p' | sort | uniq`

    Log DEBUG " --MEMORY_TOTAL=$MEMORY_TOTAL"
    Log DEBUG " --MEMORY_FREE=$MEMORY_FREE"
    Log DEBUG " --MEMORY_SLOT=$MEMORY_SLOT"
    Log DEBUG " --MEMORY_NUMBER=$MEMORY_NUMBER"
    Log DEBUG " --MEMORY_SPEED=$MEMORY_SPEED"
    
    Log SUCC "Get Memory info successful."

}






######################################################################
# 作用: 获取服务器 Disk 信息
# 用法: Get_DiskInfo
# 注意：
######################################################################
Get_DiskInfo() {

    Log DEBUG "${COLOR_YELLOW}Getting Disk info...${COLOR_CLOSE}"

    # formated lsblk
    blkinfo=`lsblk | sed '/disk/{x;p;x;}' | sed -n '1!p'`

    # if there are mutlipath
    if echo "$blkinfo" | grep -q mpath; then
        Log WARN "mutlipath found, disk info might not correct."
    #   dmsetup remove_all
    fi

    # disk list & count
    DISK_LIST=`echo "$blkinfo" | grep disk | awk '{print $1}' | xargs`
    DISK_PATH=`lsscsi | grep disk | awk '{print $NF}' | xargs`
    DISK_COUNT=`echo ${DISK_LIST} | wc -w | xargs`

    # root disk
    DISK_ROOTTYPE=`echo "$blkinfo" | grep -w "/" | awk '{print $(NF-1)}'`

    # get the root volume/partition
    root_vol_or_part=`lsblk  --output NAME,MOUNTPOINT -P | grep "MOUNTPOINT=\"/\"" | sed -n 's/NAME="\(.*\)" MOUNTPOINT=.*/\1/p'`
    # get the root disk name
    DISK_ROOT=`echo "$blkinfo" | sed -e '/./{H;$!d;}' -e "x;/$root_vol_or_part/!d;" | grep -w "disk" | awk '{print $1}'`


    # get the boot volume/partition
    boot_vol_or_part=`lsblk  --output NAME,MOUNTPOINT -P | grep "MOUNTPOINT=\"/boot\"" | sed -n 's/NAME="\(.*\)" MOUNTPOINT=.*/\1/p'`
    # get the boot disk name
    if [ -n "$boot_vol_or_part" ]; then
        DISK_BOOT=`echo "$blkinfo" | sed -e '/./{H;$!d;}' -e "x;/$boot_vol_or_part/!d;" | grep -w "disk" | awk '{print $1}'`
    else
        DISK_BOOT=$DISK_ROOT
    fi


    # disk in lvm
    unset DISK_INLVM_RAID
    for i in $DISK_LIST; do
        # in lvm
        if pvs 2>/dev/null | grep -wq $i; then
            DISK_INLVM_RAID="$DISK_INLVM_RAID $i"
        fi

        # TODO: in soft raid(need to test)
        if grep "${i}[p1-9]\[[0-9]\]" /proc/mdstat ; then
            DISK_INLVM_RAID="$DISK_INLVM_RAID $i"
        fi
    done

    DISK_INLVM_RAID=`echo $DISK_INLVM_RAID`

    # get all disk size & raid
    _ROOT_DISK_SIZE=`fdisk -l /dev/$DISK_ROOT 2>/dev/null | grep bytes | sed -n '1p' | awk '{print $(NF - 3)}'`
    DISK_ROOTSIZE="$((`echo $_ROOT_DISK_SIZE | tr ' ' '*'`/1000/1000/999))"

    DISK_RAIDCARD=`lspci | grep -i raid | awk -F':' '{print $3}'`
    DISK_RAIDCARD=`echo $DISK_RAIDCARD`
    DISK_RAIDCARD=${DISK_RAIDCARD:-none}

    unset DISK_SIZE DISK_ISINRAID
    for i in $DISK_LIST; do
        _DISK_SIZE=`fdisk -l /dev/$i 2>/dev/null | grep bytes | sed -n '1p' | awk '{print $(NF - 3)}'`
        DISK_SIZE="$DISK_SIZE $i:$((`echo $_DISK_SIZE | tr ' ' '*'`/1000/1000/999))"

        # check if disk in raid(1 in radi, 0 not in raid)
        _DISK_ISINRAID=`if hdparm -i /dev/$i 2>/dev/null | grep -q Model; then echo 0; else echo 1; fi`
        DISK_ISINRAID="$DISK_ISINRAID $i:$_DISK_ISINRAID"
    done
    DISK_SIZE=`echo $DISK_SIZE`
    DISK_ISINRAID=`echo $DISK_ISINRAID`


    # mounted disk
    unset DISK_MOUNTED
    for i in $DISK_LIST; do
        if mount | grep -q $i; then
            DISK_MOUNTED="$DISK_MOUNTED $i"
        fi
    done
    DISK_MOUNTED=`echo $DISK_MOUNTED | xargs`

    # TODO: ssd disk? there is no good idea to test ssd (if ssds are in raid card)
    # ++ if can not auto check, prompt use to select?
    # ++ maybe the only way is to test disk speed :(


    # test disk sata or ssd
    unset DISK_ROTATION_RATE_LIST
    scsi_disk_info=`lsscsi | grep disk`
    
    if [ -z "$scsi_disk_info" ]; then
    
        # use blkid to detect
        disk_path=`blkid | awk -F': ' '{print $1}'`
        
        # is vm?
        if echo $disk_path | grep -q "/dev/vd[a-z]"; then
            Log DEBUG " --$disk_path is $disk_path, might be a vm"
            disk_rotation_rate="unknown"
        else
            # test disk info
            disk_info=`smartctl -i $disk_path`

            # get the disk Rotation Rate
            disk_rotation_rate=`echo "$disk_info" | grep "Rotation Rate" | awk -F':' '{print $2}'`
            [ -z "$disk_rotation_rate" ] && disk_rotation_rate="unknown"

            # get disk rotation rate
            DISK_ROTATION_RATE_LIST="$DISK_ROTATION_RATE_LIST ${disk_path}:'${disk_rotation_rate}'"

        fi
            
    else
        while read line; do

            disk_path=`echo $line | awk '{print $NF}'`
            raidcard_brand=`echo $line | awk '{print $3}'`
            
            # if is ATA
            if [ "$raidcard_brand" = "ATA"]; then

                Log DEBUG " --$disk_path is JBOD mode"

                # test disk info
                disk_info=`smartctl -i $disk_path`

                # get the disk Rotation Rate
                disk_rotation_rate=`echo "$disk_info" | grep "Rotation Rate" | awk -F':' '{print $2}'`
                [ -z "$disk_rotation_rate" ] && disk_rotation_rate="unknown"

                # get disk rotation rate
                DISK_ROTATION_RATE_LIST="$DISK_ROTATION_RATE_LIST ${disk_path}:'${disk_rotation_rate}'"

            # if it is LSI raid, use "MegaCli64 -pdlist –aALL"
            elif [ "$raidcard_brand" = "LSI" ]; then

                Log DEBUG " --$disk_path under control $raidcard_brand"

                MEGACLI="/opt/MegaRAID/MegaCli/MegaCli64"

                # TODO: currently, only LSI raid card support

                # show all the physical disk info
                MEGA_PDLIST_INFO=`$MEGACLI -PDList -aAll`

                # "scsi_dev_num" get from lsscsi
                scsi_dev_num=`echo $line | awk '{print $1}' | awk -F':' '{print $3}'`

                # get the slot number of MEGA_PDLIST_INFO
                this_slot_info=`echo "$MEGA_PDLIST_INFO" | sed -n "/Slot Number: $scsi_dev_num/, /Drive has flagged a S.M.A.R.T alert/p"`

                # get the disk info
                disk_rotation_rate=`echo "$this_slot_info" | grep "Media Type" | awk -F':' '{print $2}' | sed -n '1p'`
                disk_rotation_rate=`echo $disk_rotation_rate`

                DISK_ROTATION_RATE_LIST="$DISK_ROTATION_RATE_LIST ${disk_path}:'${disk_rotation_rate}'"

            # other not been tested
            else
                Log ERROR "i DO NOT know the disk $disk_path under control raid card: $raidcard_brand, now only support LSI(MegaRaid) and JBOD"
            fi

        done <<<"$scsi_disk_info"
    fi

    DISK_ROTATION_RATE_LIST=`echo $DISK_ROTATION_RATE_LIST`

    # [ -z "$DISK_ROTATION_RATE_LIST" ] && Log ERROR "can NOT get the disk rotation rate info!!"

    # get the sata & ssd disk
    unset DISK_SSD DISK_SATA
    for i in $DISK_LIST; do
        if echo $DISK_ROTATION_RATE_LIST | sed "s/' /'\n/g" | grep -w $i | grep -q "Solid State Device"; then
            DISK_SSD="$DISK_SSD $i"

        else
            DISK_SATA="$DISK_SATA $i"

        fi
    done


    DISK_SATA=`echo $DISK_SATA`
    DISK_SSD=`echo $DISK_SSD`

    Log DEBUG " --DISK_LIST=\"$DISK_LIST\""
    Log DEBUG " --DISK_PATH=\"$DISK_PATH\""
    Log DEBUG " --DISK_SIZE=\"DISK_SIZE\""
    Log DEBUG " --DISK_COUNT=$DISK_COUNT"
    Log DEBUG " --DISK_ROOT=$DISK_ROOT"
    Log DEBUG " --DISK_BOOT=$DISK_BOOT"
    Log DEBUG " --DISK_ROOTTYPE=$DISK_ROOTTYPE"
    Log DEBUG " --DISK_INLVM_RAID=\"$DISK_INLVM_RAID\""
    Log DEBUG " --DISK_ROOTSIZE=$DISK_ROOTSIZE"
    Log DEBUG " --DISK_RAIDCARD=\"$DISK_RAIDCARD\""
    Log DEBUG " --DISK_ROTATION_RATE_LIST=\"$DISK_ROTATION_RATE_LIST\""
    Log DEBUG " --DISK_ISINRAID=\"$DISK_ISINRAID\""
    Log DEBUG " --DISK_SATA=\"$DISK_SATA\""
    Log DEBUG " --DISK_SSD=\"$DISK_SSD\""
    Log DEBUG " --DISK_MOUNTED=\"$DISK_MOUNTED\""

    Log SUCC "Get Disk info successful."

}



######################################################################
# 作用: 获取服务器 Network 信息
# 用法: Get_NetInfo
# 注意：
######################################################################
Get_NetInfo() {

    # TODO: get the ip and ether need to be more test!!! it is not stable
    # ++ I do not want to do it at this time...

    Log DEBUG "Get NETWORK info..."

    NET_DEV_PREFIX="br bond eth en em"


    NETWORK_PCI_INFO=`lspci | grep "Ethernet controller"`
    NETWORK_PCIETHER_COUNT=`echo "$NETWORK_PCI_INFO" | wc -l`

    NETWORK_PCIETHER_1G_COUNT=`echo "$NETWORK_PCI_INFO" | grep " Gigabit " | wc -l`
    NETWORK_PCIETHER_1G_BRAND=`echo "$NETWORK_PCI_INFO" | grep " Gigabit " | \
    sed  "s/.*Ethernet controller: \(.*\) Network Connection/\1/" | sort | uniq`

    NETWORK_PCIETHER_10G_COUNT=`echo "$NETWORK_PCI_INFO" | grep " 10-Gigabit " | wc -l`
    NETWORK_PCIETHER_10G_BRAND=`echo "$NETWORK_PCI_INFO" | grep " 10-Gigabit " | \
    sed "s/.*Ethernet controller: \(.*\) Network Connection/\1/" | sort | uniq`

    NETWORK_ALLETHERS=`ip a | egrep '^[0-9]*:' | awk '{ print $2 }' | grep -v lo | tr -d ':'`
    NETWORK_ALLETHERS=`echo $NETWORK_ALLETHERS`

    # get the physical ether
    unset NETWORK_PHYETHERS
    for i in $NETWORK_ALLETHERS; do
        if ethtool $i | grep "Supported ports" | egrep -q "FIBRE|TP"; then
            NETWORK_PHYETHERS="$NETWORK_PHYETHERS $i"
        fi
    done
    NETWORK_PHYETHERS=`echo $NETWORK_PHYETHERS`

    NETWORK_PHYETHERS_COUNT=`echo $NETWORK_PHYETHERS | wc -w`

    [ $NETWORK_PCIETHER_COUNT -ne $NETWORK_PHYETHERS_COUNT ] && \
    Log ERROR "NETWORK_PCIETHER_COUNT=$NETWORK_PCIETHER_COUNT; NETWORK_PHYETHERS_COUNT=$NETWORK_PHYETHERS_COUNT"


    # add a temp ip to unlinkd ether
    for i in $NETWORK_PHYETHERS; do

        # linked status
        if ! ifconfig $i | grep -q inet; then
            ifconfig $i 0.0.0.0
            ifconfig $i up
            Log DEBUG " --adding a temp address to test link status of $i"
        fi

    done

    sleep 8

    # get the network card info
    unset NETWORK_PHYETHERS_INFO
    for i in $NETWORK_PHYETHERS; do
        unset nc_speed nc_linked nc_mac
        nc_info=`ethtool $i`
        nc_mac=`ip addr show $i | grep "link\/ether" | sed  's/.*link\/ether \(.*\) brd.*/\1/'`
        nc_speed=`echo "$nc_info" | grep "Speed:" | sed "s/.*Speed: \(.*\)/\1/"`
        # if nc_speed has Speed Unknown
        if echo $nc_info | grep Speed | grep -q "Unknown"; then
            for j in 10000baseT 1000baseT 100baseT 100baseT 10baseT; do
                if echo "$nc_info" | grep -q "$j"; then
                    nc_speed=$j
                    break
                else
                    continue
                fi

            done

        fi
        echo $nc_speed | grep -q "Unknown" && Log ERROR "can NOT get the nc_speed for $i"



        nc_linked=`echo "$nc_info" | grep "Link detected:" | awk '{print $3}'`

        [ -z "$nc_mac" ] && Log ERROR "get $i mac address failed"
        [ -z "$nc_speed" ] && Log ERROR "get $i speed failed"
        [ -z "$nc_linked" ] && Log ERROR "get $i linked status failed"

        #nc,mac,speed,linked
        NETWORK_PHYETHERS_INFO="$NETWORK_PHYETHERS_INFO $i,$nc_mac,$nc_speed,$nc_linked"
    done
    NETWORK_PHYETHERS_INFO=`echo $NETWORK_PHYETHERS_INFO`


    # NET_USE_ETHER alreay geted from settings.conf

    # get the NET_USE_ETHER type(only support bridge or bond now, other mode not support)
    if ! echo $NETWORK_PHYETHERS | grep -wq $NET_USE_ETHER; then

        # if linux bridge
        if ! brctl show $NET_USE_ETHER 2>/dev/null | grep -q "Operation not supported"; then
            NET_USE_ETHER_TYPE=bridge

        # if linux bond
        elif cat /proc/net/bonding/* | grep -q $NET_USE_ETHER; then
            NET_USE_ETHER_TYPE=bond

        else
            NET_USE_ETHER_TYPE=unknown

        fi

    else
        NET_USE_ETHER_TYPE=raw

    fi

    IP_ADDRESS_NETMASK=`ifconfig $NET_USE_ETHER | grep "inet" | \
    sed "s/inet \(.*\) netmask \(.*\) broadcast .*/\1 \2/" | head -1 | xargs`
    # Other ip get method
    # ip addr show eth0|awk '/inet /{split($2,x,"/");print x[1]}'
    # ifconfig eth0| awk '{if ( $1 == "inet" && $3 ~ /^Bcast/) print $2}' | awk -F: '{print $2}'
    # ifconfig -a|grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'|head -1
    # ifconfig -a|perl -e '{while(<>){if(/inet (?:addr:)?([\d\.]+)/i){print $1,"\n";last;}}}'


    # Another way to get ip address is:
    #IP_ADDRESS=`ip addr show eth0 | awk '/inet /{split($2,x,"/");print x[1]}'`
    NETWORK_IPADDR=`echo ${IP_ADDRESS_NETMASK} | awk '{print $1}'`
    NETWORK_IPMASK=`echo ${IP_ADDRESS_NETMASK} | awk '{print $2}'`

    NETWORK_GATEWAY=`grep "^GATEWAY" /etc/sysconfig/network-scripts/ifcfg-$NET_USE_ETHER | awk -F"=" '{print $2}' | sed -n '1p'`

    [ -z "$NETWORK_GATEWAY" ] && NETWORK_GATEWAY=`netstat -rn | grep "UG" |grep "^0.0.0.0" | sed -n '1p' | awk '{print $2}'` && \
    Log WARN "can NOT find \"GATEWAY\" in ifcfg-$NET_USE_ETHER, use \"ip route\" to get GATEWAY=$NETWORK_GATEWAY"

    # Or the other method to Get active GATEWAY
    # ip route | sed -n 's/.*via \(.*\) dev.*/\1/p' | head -1

    NETWORK_DNS=`grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | xargs | tr ' ' ','`
    NETWORK_DOMAIN=`grep ^search /etc/resolv.conf | awk '{print $2}' | xargs | tr ' ' ','`



    Log DEBUG " --NETWORK_PCIETHER_COUNT=$NETWORK_PCIETHER_COUNT"
    Log DEBUG " --NETWORK_PCIETHER_1G_COUNT=$NETWORK_PCIETHER_1G_COUNT"
    Log DEBUG " --NETWORK_PCIETHER_1G_BRAND=\"$NETWORK_PCIETHER_1G_BRAND\""

    Log DEBUG " --NETWORK_PCIETHER_10G_COUNT=$NETWORK_PCIETHER_10G_COUNT"
    Log DEBUG " --NETWORK_PCIETHER_10G_BRAND=\"$NETWORK_PCIETHER_10G_BRAND\""

    Log DEBUG " --NETWORK_ALLETHERS=\"$NETWORK_ALLETHERS\""
    Log DEBUG " --NETWORK_PHYETHERS=\"$NETWORK_PHYETHERS\""
    Log DEBUG " --NETWORK_PHYETHERS_INFO=\"$NETWORK_PHYETHERS_INFO\""

    Log DEBUG " --NET_USE_ETHER=$NET_USE_ETHER"
    Log DEBUG " --NET_USE_ETHER_TYPE=$NET_USE_ETHER_TYPE"
    Log DEBUG " --NETWORK_IPADDR=$NETWORK_IPADDR"
    Log DEBUG " --NETWORK_IPMASK=$NETWORK_IPMASK"
    Log DEBUG " --NETWORK_GATEWAY=$NETWORK_GATEWAY"
    Log DEBUG " --NETWORK_DNS=$NETWORK_DNS"
    Log DEBUG " --NETWORK_DOMAIN=$NETWORK_DOMAIN"

    Log DEBUG ""




}


######################################################################
# 作用: 生成主机的所有信息文件
# 用法: Gen_HostInfo
# 注意：
######################################################################
Gen_HostInfo() {

    Log DEBUG "finish check information and ready to push"

    cat <<EOF >/etc/${HOSTINFO_FILE}
[system]
    SYSTEM_MANUFACTURER="$SYSTEM_MANUFACTURER"
    SYSTEM_PRODUCTNAME="$SYSTEM_PRODUCTNAME"
    SYSTEM_SERIALNUMBER="$SYSTEM_SERIALNUMBER"
    SYSTEM_UUID="$SYSTEM_UUID"

[os]
    OS_DISTRIBUTION="$OS_DISTRIBUTION"
    OS_FAMILY="$OS_FAMILY"
    OS_VERSION="$OS_VERSION"
    OS_ARCH="$OS_ARCH"
    OS_HOSTNAME="$OS_HOSTNAME"
    OS_HOSTID="$OS_HOSTID"

[cpu]
    CPU_PHYSICAL=$CPU_PHYSICAL
    CPU_CORE=$CPU_CORE
    CPU_THREAD=$CPU_THREAD
    CPU_SPEED=$CPU_SPEED
    CPU_FAMILY=$CPU_FAMILY
    CPU_MODELNAME="$CPU_MODELNAME"

[mem]
    MEMORY_TOTAL=$MEMORY_TOTAL
    MEMORY_FREE=$MEMORY_FREE
    MEMORY_SLOT=$MEMORY_SLOT
    MEMORY_NUMBER=$MEMORY_NUMBER
    MEMORY_SPEED="$MEMORY_SPEED"

[disk]
    DISK_LIST="$DISK_LIST"
    DISK_PATH="$DISK_PATH"
    # note: disk size get from disk information, not disk capacity
    # use disk capacity when you format disk(eg: lsblk)
    DISK_SIZE="$DISK_SIZE"
    DISK_COUNT=$DISK_COUNT
    DISK_ROOT="$DISK_ROOT"
    DISK_BOOT="$DISK_BOOT"
    DISK_ROOTTYPE="$DISK_ROOTTYPE"
    DISK_RAIDCARD="$DISK_RAIDCARD"
    DISK_ROOTSIZE=$DISK_ROOTSIZE
    DISK_INLVM_RAID="$DISK_INLVM_RAID"
    DISK_ISINRAID="$DISK_ISINRAID"
    DISK_MOUNTED="$DISK_MOUNTED"
    DISK_ROTATION_RATE_LIST="$DISK_ROTATION_RATE_LIST"
    DISK_SATA="$DISK_SATA"
    DISK_SSD="$DISK_SSD"

[network]
    NETWORK_PCIETHER_COUNT=$NETWORK_PCIETHER_COUNT
    NETWORK_PCIETHER_1G_COUNT=$NETWORK_PCIETHER_1G_COUNT
    NETWORK_PCIETHER_1G_BRAND="$NETWORK_PCIETHER_1G_BRAND"
    NETWORK_PCIETHER_10G_COUNT=$NETWORK_PCIETHER_10G_COUNT
    NETWORK_PCIETHER_10G_BRAND="$NETWORK_PCIETHER_10G_BRAND"
    NETWORK_ALLETHERS="$NETWORK_ALLETHERS"
    NETWORK_PHYETHERS="$NETWORK_PHYETHERS"
    NETWORK_PHYETHERS_INFO="$NETWORK_PHYETHERS_INFO"
    NET_USE_ETHER="$NET_USE_ETHER"
    NET_USE_ETHER_TYPE=$NET_USE_ETHER_TYPE
    NETWORK_IPADDR="$NETWORK_IPADDR"
    NETWORK_IPMASK="$NETWORK_IPMASK"
    NETWORK_GATEWAY="$NETWORK_GATEWAY"
    NETWORK_DNS="$NETWORK_DNS"
    NETWORK_DOMAIN="$NETWORK_DOMAIN"

EOF

}


######################################################################
# 作用: 将服务器 system/os/cpu/mem/disk/network 信息 push 至 ceph-ai
# 用法:
# 注意：最终生成的info文件会回传至deploy host
######################################################################
Push_HostInfo() {

    # push the hardware info
    Log DEBUG "push hostinfo file to ceph-ai"
    Pusher FILE ${RUN_DIR}/${HOSTINFO_FILE}


}


######################################################################
# 作用: 判断 OS 发行版
# 用法: Check_OS_Distrib 
# 注意：
######################################################################
Check_OS_Distrib(){

   RELEASE_FILE=/etc/*-release
   if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" $RELEASE_FILE; then
       OS=CentOS
       PKG_INST_CMD="yum -y install"
       RELEASE_FILE=/etc/centos-release
       
   elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" $RELEASE_FILE; then
       OS=Debian
       PKG_INST_CMD="apt -y install"
       RELEASE_FILE=/etc/lsb-release
       
   elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" $RELEASE_FILE; then
       OS=Ubuntu
       PKG_INST_CMD="apt -y install"
        RELEASE_FILE=/etc/lsb-release
       
   elif grep -Eqi "Alpine" /etc/issue || grep -Eq "Alpine" $RELEASE_FILE; then
       OS=Alpine
       PKG_INST_CMD="apk -y -q install"
        RELEASE_FILE=/etc/lsb-release
        
   else
       echo "Not support OS, Please reinstall OS and retry!"
       return 1
   fi
}



######################################################################
# 作用: 用于判断OS的大版本
# 用法: Check_CentOS_Version 7，如果是指定的RHEL/CENTOS版本，则返回0; 
#       否则返回1,非RHEL或CENTOS返回2
# 注意：
######################################################################
Check_CentOS_Version() {

    if [ "$#" -ne 1 ]; then
        Log ERROR "Function Check_CentOS_Version() error! Usage: Check_OS <VERSION_NUMBER>\n"
    fi
    local N=$1
    if [ -f /etc/redhat-release ] ; then
        if grep -q " $N.[0-9]" /etc/redhat-release; then
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}










