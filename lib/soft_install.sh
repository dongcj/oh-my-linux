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
# 作用: 将当前运行机器上的 文件/消息/函数 回推给 installer,
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
    
    softlist="bash-completion bc bmon ethtool fio  hdparm  htop \
    ipmitool iotop ifstat locales  lsscsi  mycli net-tools \
    nmon ntp  pciutils python-pip  rsync smartmontools wget"
    softlist=`echo $softlist`

    # add chkconfig for ubuntu
    if [ "$OS" = "Ubuntu" ]; then
    
        # prepare the apt
        Run dpkg --configure -a
        Run apt -y autoremove
        
        which chkconfig || { rm -rf /usr/bin/chkconfig && \
        Run $PKG_INST_CMD sysv-rc-conf rcconf && \
        Run ln -s /usr/sbin/sysv-rc-conf /usr/bin/chkconfig; }
        
    elif [ "$OS" = "CentOS" ]; then
        if ! rpm -qa | grep -iq epel; then
            yum install -y epel-release
         fi
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
# 作用: 设置本机Hosts
# 用法: Gen_Hosts_File
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
# 作用: 检查服务器的网络接口
# 用法: Check_Network
# 注意：
######################################################################
Network_CheckDevice() {

    ：
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










