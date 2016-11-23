#!/bin/bash
## CopyRight  dongchaojun@GreatWall
## Author:dongcj dongcj@greatwall.com.cn
## Usage: deploy.sh -standby      ------install the server as a standby server
## Modify Log:
# 2012-12-24: Add the password check.

## Define the directory and file location
LOG_DIR=/opt/installtmp/
DEPLOY_LOGNAME=deploy.log
DEPLOY_CONFNAME=deploy.conf
SCRIPT_NAME=`basename $0`
RELEASE_FILE=/etc/redhat-release
AUTORUN_FILE=/etc/rc.d/rc.local
DVD_UPLOAD_DIR=/opt/
CUR_DIR=$(echo `dirname $0` | sed -n 's/$/\//p')
#CUR_FILE=`echo "$CUR_DIR" | sed -e "s/.*\/\([a-zA-Z0-9]\)/\1/"`
export CUR_DIR; cd ${CUR_DIR}
export TERM=xterm LANG=C
PWD_DIR=`pwd`
[ ! -d "$LOG_DIR" ] && mkdir -p $LOG_DIR
SCRIPT_START_TIME=`date "+%Y-%m-%d %H:%M:%S"`
set -o ignoreeof

# show wait information
echo -n "   Collecting system information, please wait..."


## Exit prompt
stty erase '^H'
trap TrapProcess 2 3
TrapProcess(){
    [ -n "$BG_PID" ] && kill -9 $BG_PID
    echo;  echo; echo "   USER EXIT !!"; echo
    stty erase '^?'
    exit 1
}


## Check the user   
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && exit 1

## define the system variables
SSH="ssh -o StrictHostKeyChecking=no"
BOLD=`tput bold`
SMSO=`tput smso`
UNDERLINE=`tput smul`
NORMAL=`tput sgr0`


## Import the conf from file deploy.conf
if [ -f $DEPLOY_CONFNAME ];then
    [ -w $DEPLOY_CONFNAME ] && sed -i "s/[ \t]*=[ \t]*/=/g" $DEPLOY_CONFNAME
    if ! source $DEPLOY_CONFNAME >/dev/null 2>&1;then
        echo "   Please check the $DEPLOY_CONFNAME!"; exit 1
    fi
fi

## Check the system installation mode
if ! echo $@ | grep "\-standby" >/dev/null 2>&1; then
    SERVER_INSTALL_MODE=PRIMARY
else
    SERVER_INSTALL_MODE=SECONDARY
fi

## Check the server(selected installation mode) is already succeed?
if [ -f ${LOG_DIR}${DEPLOY_CONFNAME} ]; then
    if grep -iq "DEPLOY_IS_SUCCESSFUL=yes" ${LOG_DIR}${DEPLOY_CONFNAME}; then
        LAST_SERVER_INSTALL_MODE=`awk -F"=" '/SERVER_INSTALL_MODE/ {print $2}' ${LOG_DIR}${DEPLOY_CONFNAME}`
        while true; do
            echo
            echo -n "   This Server is already successful deployed as \"$LAST_SERVER_INSTALL_MODE\", do you really want to deploy again? [y/n]: "
            read -n1 ANS
            case $ANS in
                Y|y)break;
                ;;
                N|n)echo;exit 0
                ;;
                *)continue
                ;;
            esac
        done
    fi
fi      

## Get the system information
[ -f "$RELEASE_FILE" ] || { echo "   Not RedHat/CentOS Linux? exit"; exit 1;}
OS_DISTRIBUTION=`sed -n '1p' $RELEASE_FILE | awk '{OFS=" ";print $1" "$2" "}' | xargs`
[ "$OS_DISTRIBUTION" != "Red Hat" -a "$OS_DISTRIBUTION" != "CentOS release" ] && { \
    echo "   Not RedHat/CentOS Linux? exit"; exit 1;}
OS_FAMILY=`uname`
[ "$OS_FAMILY" != "Linux" ] && echo "   Not RedHat/CentOS Linux? exit" && exit 1
OS_VERSION=`cat $RELEASE_FILE | awk '{print $((NF-1))}'`
[ ${OS_VERSION:0:1} -ge 6 ] 2>/dev/null || { echo "   RedHat/CentOS version must greater than 6, exit"; exit 1;}
OS_ARCH=`arch`;OS_BIT=`getconf LONG_BIT`
OS_HOST_ID=`hostid`
HOST_NAME=`hostname -s`

DMIDECODE=`dmidecode -t system`
SYSTEM_MANUFACTURER=`echo "$DMIDECODE" | grep 'Manufacturer' | head -n 1 | cut -f 2 -d':' | xargs`
SYSTEM_PRODUCT_NAME=`echo "$DMIDECODE" | grep 'Product Name' | head -n 1 | cut -f 2 -d':' | xargs`
SYSTEM_SERIAL_NUMBER=`echo "$DMIDECODE" | grep 'Serial Number' | head -n 1 | cut -f 2 -d':' | xargs`
SYSTEM_UUID=`echo "$DMIDECODE" | grep 'UUID' | head -n 1 | cut -f 2 -d':' | xargs`

# Use numactl can get the cpu node info
# VIRTUAL_CPUS=`grep "name" /proc/cpuinfo | cut -f2 -d: | uniq -c | awk '{print $1}'`
VIRTUAL_CPUS=`egrep -c 'processor([[:space:]]+):.*' /proc/cpuinfo`
PHYSICAL_CPUS=`grep "physical id" /proc/cpuinfo | sort | uniq | wc -l`
((PHYSICAL_CPUS=$PHYSICAL_CPUS==0?1:$PHYSICAL_CPUS))
# if cpu has HT, one core has more than 2 (inclue 2) threads;
CPU_IF_HT=`if [ $(grep "core id" /proc/cpuinfo | grep -w 0 | wc -l) -ge 2 ]; then echo 1; else echo 0;fi`
# 
CPU_CORE=`if [ "$CPU_IF_HT" -eq 1 ];then printf "%d" $((VIRTUAL_CPUS/2));else echo $VIRTUAL_CPUS;fi`
CPU_SPEED_MHZ=`grep 'cpu MHz' /proc/cpuinfo | sort | sed -n '$p' | awk '{printf "%d", $NF}'`
CPU_FAMILY=`if grep AuthenticAMD /proc/cpuinfo >/dev/null; then echo AMD; elif grep \
            Intel /proc/cpuinfo >/dev/null; then echo Intel; else echo unknown; fi`
CPU_MODEL_NAME=`grep "model name" /proc/cpuinfo | uniq | awk -F":" '{print $2}' | sed 's/           / /'`

_MEMORY_SIZE=`cat /proc/meminfo | grep MemTotal | awk  '{print $2}'`
MEMORY_SIZE=`printf "%G" $(echo "scale = 2; $_MEMORY_SIZE/1000/1000" | bc)`
_MEMORY_FREE=`cat /proc/meminfo | grep MemFree | awk  '{print $2}'`
MEMORY_FREE=`printf "%G" $(echo "scale = 2; $_MEMORY_FREE/1000/1000" | bc)`

# DISK_LIST=`fdisk -l 2>/dev/null | grep -w "/dev/[shv]d[a-z]:" | awk '{print $2}' | tr -d ':' | awk -F"/" '{print $NF}' | xargs`
# clear the disk mpath info
if lsblk | grep -q mpath; then
    while true; do
        echo -n "   Found mpath, Ready to clear it, \"Y\" to continue: "
        read -n1 ANS
        ANS=${ANS:0:1}
        case ${ANS} in
            Q|q|N|n|no|No)echo; exit 0;
            ;;
            Y|y|yes|Yes)dmsetup remove_all; break;
            ;;
            *)echo;echo;continue;
        esac
    done
fi
    
DISK_LIST=`lsblk | grep disk | awk '{print $1}' | xargs`
DISK_COUNT=`echo ${DISK_LIST} | wc -w | xargs`
ROOT_DISK=`echo $DISK_LIST | awk '{print $1}'`
_ROOT_DISK_SIZE=`fdisk -l /dev/$ROOT_DISK 2>/dev/null | grep bytes | sed -n '1p' | awk '{print $(NF - 1)}'`
ROOT_DISK_SIZE="$((`echo $_ROOT_DISK_SIZE | tr ' ' '*'`/1000/1000/1000))"
#get all disk size & raid(not sure the hdparm -i)
unset DISK_SIZE
for i in $DISK_LIST; do
    _DISK_SIZE=`fdisk -l /dev/$i 2>/dev/null | grep bytes | sed -n '1p' | awk '{print $(NF - 1)}'`
    DISK_SIZE="$DISK_SIZE $((`echo $_DISK_SIZE | tr ' ' '*'`/1000/1000/1000))"
    _DISK_RAID=`if hdparm -i /dev/$i 2>/dev/null | grep -q Model; then echo 1; else echo 0; fi`
    DISK_RAID="$DISK_RAID $_DISK_RAID"
done
DISK_SIZE=`echo $DISK_SIZE`
DISK_RAID=`echo $DISK_RAID`

# get all disk speed MB, (no need by this server but the storage node)
####################################
# TEST_COUNT=3
# while [ $TEST_COUNT -gt 0 ]; do TEST_COUNT=`expr $TEST_COUNT - 1`; hdparm -t /dev/$DISK_LIST >>/tmp/test_disk_speed.tmp 2>&1; done &
# TEST_DISK_SPEED_PID=$!



#get the ether list
NET_DEV_PREFIX="^eth|^em|^br|^bond"
NET_ETHER_LIST=`ifconfig -a | egrep '^[^ ]' | awk '{ print $1 }' | egrep "${NET_DEV_PREFIX}" | xargs`
[ -z "$NET_ETHER_LIST" ] && echo "   Can not get the network ether list, exit" && exit 1

#get the first ip & mask
FIRST_NET_ETHER=$(echo "$NET_ETHER_LIST" | awk '{print $1}')
IP_ADDRESS_NETMASK=`ifconfig $FIRST_NET_ETHER | grep "inet addr" | sed "s/inet addr:\(.*\) Bcast:.* Mask:\(.*\)/\1 \2/" | head -1 | xargs`
# Other ip get method
# ip addr show eth0|awk '/inet /{split($2,x,"/");print x[1]}'
# ifconfig eth0| awk '{if ( $1 == "inet" && $3 ~ /^Bcast/) print $2}' | awk -F: '{print $2}'
# ifconfig -a|grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'|head -1
# ifconfig -a|perl -e '{while(<>){if(/inet (?:addr:)?([\d\.]+)/i){print $1,"\n";last;}}}'


# Another way to get ip address is:
#IP_ADDRESS=`ip addr show eth0 | awk '/inet /{split($2,x,"/");print x[1]}'`
IP_ADDRESS=`echo ${IP_ADDRESS_NETMASK} | awk '{print $1}'`
IP_NETMASK=`echo ${IP_ADDRESS_NETMASK} | awk '{print $2}'`

#get the first ip up on which ether
for i in ${NET_ETHER_LIST};do
    if ifconfig $i | grep "$IP_ADDRESS" >/dev/null 2>&1; then
        IP_ADDRESS_ETHER=$i
        IP_ADDRESS_MAC=`ifconfig $i | grep HWaddr | awk '{print $NF}'`
        break
    fi
done
[ -z "$IP_ADDRESS_ETHER" ] && echo "   Can not get the ether which have the ip address, exit" && exit 1
[ -z "$IP_ADDRESS_MAC" ] && echo "   Can not get the MAC which have the ip address, exit" && exit 1
IP_GATEWAY=`grep "^GATEWAY" /etc/sysconfig/network-scripts/ifcfg-$IP_ADDRESS_ETHER | awk -F"=" '{print $2}'`
# Get active GATEWAY
# ip route | sed -n 's/.*via \(.*\) dev.*/\1/p' | head -1

[ -z "$IP_GATEWAY" ] && IP_GATEWAY=`route -n | grep "^0.0.0.0" | grep "$IP_ADDRESS_ETHER" | xargs | cut -d' ' -f2`
IP_DNS=`grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | xargs | tr ' ' ','`
IP_DOMAIN=`grep ^search /etc/resolv.conf | awk '{print $2}' | xargs | tr ' ' ','`


## Config selinux
# sestatus -v & getenforce to check status
SELINUX_CONF=/etc/selinux/config
CURRENT_SELINUX_VALUE=`awk -F"=" '/^SELINUX=/ {print $2}' $SELINUX_CONF`
if [ -f $SELINUX_CONF ];then
    if [ "$CURRENT_SELINUX_VALUE" != "disabled" ];then
        sed -i "/^SELINUX=/s/$CURRENT_SELINUX_VALUE/disabled/g" $SELINUX_CONF
    fi
fi
setenforce 0 >/dev/null 2>&1


## reduce security, can ssh run command remote
sudo sed -i s'/Defaults.*requiretty/#Defaults requiretty'/g /etc/sudoers


## Config the TIMEZONE to Asia/ShangHai, UTC
########################################
if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
    # remove the old localtime file
    rm -rf /etc/localtime.old && mv /etc/localtime /etc/localtime.old
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    sed -i '/^[^#]/d' /etc/sysconfig/clock
    echo "ZONE=\"Asia/Shanghai\"" >>/etc/sysconfig/clock
    echo "UTC=true" >>/etc/sysconfig/clock
    # update the systime to hardware clock
    hwclock --systohc
fi
. /etc/sysconfig/clock
ESCAPE_ZONE=$(echo $ZONE | tr ' ' '_' | sed 's/\//\\\//g')
[ "$UTC" = "true" -o "$UTC" = "yes" ] && ESCAPE_ZONE=$(echo $ESCAPE_ZONE | sed 's/^/--utc /g')
TIME_ZONE=$ESCAPE_ZONE


## Config the gdm(for X11)
GDM_CONF=/etc/gdm/custom.conf
if [ -f $GDM_CONF ]; then
    if ! sed -n '/\[security\]/,/\[xdmcp\]/p' $GDM_CONF | grep -q "AllowRemoteRoot=TRUE"; then
        sed -i '/\[security\]/a AllowRemoteRoot=TRUE' $GDM_CONF
    fi
    if ! sed -n '/\[xdmcp\]/,/$/p' $GDM_CONF | grep -q "Enable=1"; then
        sed -i '/\[xdmcp\]/a Enable=1' $GDM_CONF
    fi
    if [ -z "$DISPLAY" ]; then
        gdm-restart >/dev/null 2>&1
    fi
fi
    
## Config IPV6(old Linux)
#MODULE_CONF=/etc/modprobe.conf
#if [ -f $MODULE_CONF ];then
#    if lsmod | grep  "^ipv6" >/dev/null 2>&1;then
#        if ! grep "alias net-pf-10 off" $MODULE_CONF >/dev/null 2>&1;then
#            echo "alias net-pf-10 off" >>$MODULE_CONF
#        fi
#        if ! grep "alias ipv6 off" $MODULE_CONF >/dev/null 2>&1;then
#            echo "alias ipv6 off" >>$MODULE_CONF
#        fi
#        if ! grep "blacklist ipv6" $MODULE_CONF >/dev/null 2>&1;then
#            echo "blacklist ipv6" >>$MODULE_CONF
#        fi
#    fi
#fi

# Just disable IPv6 globally on your Linux System.
# One method:
# [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && echo 1 >/proc/sys/net/ipv6/conf/all/disable_ipv6

# The other:
# Configure it in sysctl.conf to have it across reboots
SYSCTL_CONF=/etc/sysctl.conf
if [ "`awk -F"=" '/net.ipv6.conf.all.disable_ipv6/ {print $2}' ${SYSCTL_CONF} | xargs`" != "1" ]; then
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' ${SYSCTL_CONF}
    echo " " >>${SYSCTL_CONF}
    echo "# Disable IPv6 Globally" >>${SYSCTL_CONF}
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >>${SYSCTL_CONF}
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -p >/dev/null 2>&1 
fi

# Optimized Networking Globally
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
    
    sysctl -p >/dev/null 2>&1 
fi


# Optimized Kernel Globally
if ! grep -q "Optimized Kernel Globally" ${SYSCTL_CONF}; then
    echo " " >>${SYSCTL_CONF}
    echo "# Optimized Kernel Globally" >>${SYSCTL_CONF}
    
    cat <<EOF >>${SYSCTL_CONF}
fs.file-max = 6815744
fs.aio-max-nr = 1048576
kernel.sem = 250 32000 100 128
    
EOF
    
    sysctl -p >/dev/null 2>&1 
fi
    
# 


# Ubunbu disable IPv6
# 1. vi /etc/default/grub 

# 2. change GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
#+ to     GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 quiet splash"           ## Notice: '.' not '_'   

# 3.  sudo update-grub



SYSCONFIG_NETWORK=/etc/sysconfig/network
if [ -f $SYSCONFIG_NETWORK ]; then
    if grep -q "NETWORKING_IPV6" $SYSCONFIG_NETWORK; then
        sed -i 's/NETWORKING_IPV6=.*/NETWORKING_IPV6=no/' $SYSCONFIG_NETWORK
    fi
fi


# Remove the udev presistent network file (tobe done)
PRESISTENT_NETWORK_FILE=/etc/udev/rules.d/70-persistent-net.rules




############## Config the Vim, this is also be added to the VM ####################################
# add vi alias to vim
if [ -f /root/.bashrc ]; then
    if which vim >/dev/null 2>&1; then
        grep -q "alias vi='vim'" /root/.bashrc || echo "alias vi='vim'" >>/root/.bashrc
    fi
    grep -q "alias grep='grep --color'" /root/.bashrc || echo "alias grep='grep --color'" >>/root/.bashrc
    grep -q "alias ll='ls -alrt'" /root/.bashrc || echo "alias ll='ls -alrt'" >>/root/.bashrc
fi
# set the tab=4
if [ -f /etc/vimrc ]; then
    grep -q "set tabstop" /etc/vimrc || echo "set tabstop=4" >>/etc/vimrc
fi

# alias local yum
# alias yuml='yum --disablerepo=\* --enablerepo=CentOS7.0_X64-HTTP'

## Config the system service, "service xx stop" always return 0 if the service exists
TO_DISABLE_SERVICE="ip6tables iptables cups sendmail NetworkManager avahi-daemon autofs \
					bluetooth firstboot isdn pcscd restorecond dnsmasq rhnsd rhsmcertd abrtd"
for i in $TO_DISABLE_SERVICE; do
	service $i stop >/dev/null 2>&1 && chkconfig $i off
done

for i in iptables ip6tables cups sendmail NetworkManager avahi-daemon autofs \
         bluetooth firstboot isdn pcscd restorecond dnsmasq; do
    service $i stop >/dev/null 2>&1 && chkconfig $i off
done


# ntp service start
service ntpd stop >/dev/null 2>&1 && chkconfig ntpd on


## Config the system limits
#local environment
ulimit -n 65535
ulimit -u 40960
#/etc/profile
PROFILE_CONF=/etc/profile
if ! grep -q "ulimit" $PROFILE_CONF; then
    echo "ulimit -n 65535" >>$PROFILE_CONF
    echo "ulimit -u 192098" >>$PROFILE_CONF
    echo "ulimit -i 192098" >>$PROFILE_CONF
fi
source $PROFILE_CONF
#/etc/security/limits.conf
LIMITS_CONF=/etc/security/limits.conf
grep -q "^[^#].*soft.*nproc" $LIMITS_CONF  || echo "*       soft    nproc   131072" >>$LIMITS_CONF
grep -q "^[^#].*hard.*nproc" $LIMITS_CONF  || echo "*       hard    nproc   131072" >>$LIMITS_CONF
grep -q "^[^#].*soft.*nofile" $LIMITS_CONF || echo "*       soft    nofile   655360" >>$LIMITS_CONF
grep -q "^[^#].*hard.*nofile" $LIMITS_CONF || echo "*       hard    nofile   655360" >>$LIMITS_CONF

# rh6引入了这个配置,且优先级最高,影响nproc.直接删除即可
rm -rf /etc/security/limits.d/{20,90}-nproc.conf

###############################################
## Config the SSHD Service
# UseDNS no
sed -i '/UseDNS/s/.*/UseDNS no/' /etc/ssh/sshd_config
# Make ssh faster and faster...
sed -i "/^[[:space:]]*GSSAPIAuthentication/s/.*/GSSAPIAuthentication no/" /etc/ssh/sshd_config

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
if ! grep -q dongcj /etc/banner; then
    # echo -e "\t\033[1;32mCloud Management Server($SERVER_INSTALL_MODE) by dongcj@szhcf.com.cn\033[0m" >>/etc/banner
    echo -e "\t\033[1;32mServer Management by dongcj\033[0m" >>/etc/banner
    echo >>/etc/banner
fi

sed -i '/Banner/s/.*/Banner \/etc\/banner/' /etc/ssh/sshd_config

################################ Hypervisor optimize##########################################################
# open ksm(if memory is low, but want run more vm)
#if grep -vq "echo 1 >/sys/kernel/mm/ksm/run"; then
#    echo "echo 1 >/sys/kernel/mm/ksm/run" >>/etc/rc.d/rc.local
#fi
# Add the loop device
MAKEDEV /dev/loop

# grep -P means Use Perl style re-patten; [[:space:]] means all space, include tab.
grep -Pq "MAKEDEV[[:space:]]+/dev/loop" $AUTORUN_FILE || echo "MAKEDEV /dev/loop" >>$AUTORUN_FILE


### Config the login title style
# set PS1
# export PS1=\u@\[\e[1;93m\]\h\[\e[m\]:\w\$\[\e[m\]
# export PS1='\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m`pwd`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n\$'

export PS1="
\[\033[33m\][\D{%Y-%m-%d %H:%M.%S}]\[\033[0m\]  \[\033[35m\]\w\[\033[0m\]                                                                                                           
\[\033[36m\][\u.\h]\[\033[0m\] "

# Setting history format like below
 # 999   [2016-05-03 13:39:27] vi /etc/bashrc 
 # 1000  [2016-05-03 13:39:45] export 
 # 1001  [2016-05-03 13:39:47] env
 # 1002* [2016-05-03 13:39:51] 
 # 1003  [2016-05-03 13:39:57] export  | wc -l
HISTTIMEFORMAT='[%F %T] '
HISTSIZE=2000


:<<EOF
## Check the DVD ISO is already uploaded to $DVD_UPLOAD_DIR
NUM_ISO_IN_OPT=`ls $DVD_UPLOAD_DIR | grep -E "iso$|ISO$" | wc -l | xargs`
if test $NUM_ISO_IN_OPT -gt 1;then
    echo "   There are more than one *.iso in $DVD_UPLOAD_DIR, please reserve only one!"
    exit 1
elif test $NUM_ISO_IN_OPT -eq 0;then
    echo "   Please upload the Red Hat/CentOS DVD1 to $DVD_UPLOAD_DIR directory!"
    exit 1
else
    DVD_FILE_NAME=`ls $DVD_UPLOAD_DIR | grep -E "iso$|ISO$"`
    DVD_MOUNT_DIR=/opt/dvdrepo
#mount and check the "dvd version"="current version"
    mkdir -p $DVD_MOUNT_DIR
    mount | grep "$DVD_MOUNT_DIR" >/dev/null 2>&1 && umount -f $DVD_MOUNT_DIR >/dev/null 2>/dev/null
    if mount -o loop ${DVD_UPLOAD_DIR}${DVD_FILE_NAME} $DVD_MOUNT_DIR;then
        if [ -f $DVD_MOUNT_DIR/.treeinfo ];then
            if ! grep version $DVD_MOUNT_DIR/.treeinfo | grep "$OS_VERSION" >/dev/null 2>&1;then
                echo "   Please check the DVD version is $OS_VERSION !"
                exit 1
            fi
        elif [ -f $DVD_MOUNT_DIR/media.repo ];then
            if ! grep name $DVD_MOUNT_DIR/media.repo | grep "$OS_VERSION" >/dev/null 2>&1;then
                echo "   Please check the DVD version is $OS_VERSION !"
                exit 1
            fi
        else # if there is no .treeinfo file or media.repo, version check is not complete!
            if ! ls $DVD_MOUNT_DIR | grep RPM | awk -F"-" '{print $NF}' | grep ${OS_VERSION:0:1} >/dev/null 2>&1;then
                echo "   Please check the DVD version is $OS_VERSION !"
                exit 1
            fi
        fi
        #add to the /etc/fstab
        ESCAPE_DIR=$(echo $DVD_MOUNT_DIR | sed 's/\//\\\//g')
        sed -i "/$ESCAPE_DIR/d" /etc/fstab
        echo "${DVD_UPLOAD_DIR}${DVD_FILE_NAME}	$DVD_MOUNT_DIR	iso9660	loop	0 0" >> /etc/fstab
    else
        echo "   Mount command: mount -o loop ${DVD_UPLOAD_DIR}${DVD_FILE_NAME} $DVD_MOUNT_DIR failed!"
        exit 1
    fi
fi

## Make a repo from cdrom, called "DVD-FILE.repo"
DVD_FILE_REPO=DVD-FILE
mkdir -p /etc/yum.repos.d/
cat <<EOF >/etc/yum.repos.d/${DVD_FILE_REPO}.repo
[$DVD_FILE_REPO]
name=${OS_DISTRIBUTION} - $OS_VERSION - $DVD_FILE_REPO
baseurl=file://$DVD_MOUNT_DIR/
enable=1
gpgcheck=0

# import the GPG key
rpm --import $DVD_MOUNT_DIR/RPM-GPG-KEY* >/dev/null 2>&1
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-* >/dev/null 2>&1
EOF


# Install some package, need yum support
# yum -y -nogpgcheck install bash-completion python-pip gcc pssh 
# note: bash-completion needs to reboot or run: . /etc/bash_completion


## Show the system configuration
ShowInfo(){
clear
echo
echo -n "        |-------------------------------------------------------------------"
echo -ne "\e[6n";read -sdR pos0;pos0=${pos0#*[};P0=${pos0/;/ };L0=${P0%% *};C0=${P0##* }
echo
echo -n "        |----------------- "
echo -n "${BOLD}Confirm system information...${NORMAL}"
echo " -------------------"
cat <<EOF
        |                                                                   
        |    MACHINE TYPE: ${OS_ARCH}   MACHINE NAME: ${SYSTEM_PRODUCT_NAME}        
        |                                                                   
        |    1. Disk information                                             
        |        Disk  list: ${DISK_LIST}                                  
        |        Disk  size: ${DISK_SIZE} (GB)                                 
        |        Disk count: ${DISK_COUNT}                                 
        |                                                                   
        |    2. Memory information                                           
        |        Memory total: ${MEMORY_SIZE} (GB)                                      
        |        Memory free : ${MEMORY_FREE} (GB)                                                 
        |
        |    3. CPU information                                              
        |        Virtual  CPU(s): ${VIRTUAL_CPUS}                           
        |        Physical CPU(s): ${PHYSICAL_CPUS}
        |
        |    4. Network information  
        |        Network ether(s): ${NET_ETHER_LIST}              
        |        Ip address: ${IP_ADDRESS}
        |
EOF
echo -n "        |------------------ Press \"q\" to quit, \"y\" to continue -------------"
echo -ne "\e[6n";read -sdR pos1;pos1=${pos1#*[};P1=${pos1/;/ };L1=${P1%% *};C1=${P1##* }
for ((i=$L1;i>=L0;i--));do
    tput cup `expr $i - 1` `expr $C1 - 1`;echo "|"
done
echo -e "\\033[$((L1));$((C1))H"
while true;do
echo -n "           Is the preceding information correct? [q/y default:y]: "
read -n1 ANS
ANS=${ANS:0:1}
case ${ANS} in
#        N|n)EditMenu;
#        ;;
#        E|e)EditMenu;
#        ;;
        Q|q)echo; exit 0;
        ;;
        Y|y|"")clear;break;
        ;;
          *)echo;echo;continue;
esac
done
}

Show_Confirm(){
    clear
    echo
    echo "   Here is your input:"
    echo "   --------------------------------------------------"
    echo "   Server HostName:       $CLOUD_SERVER_HOSTNAME"
    echo "   Server IP Address:     $CLOUD_SERVER_IP"
    echo "   Server NetMask:        $CLOUD_SERVER_NETMASK"
    echo "   Server GateWay:        $CLOUD_SERVER_GATEWAY"
    echo "   Server DNS Address:    $CLOUD_SERVER_DNSSERVER"
    echo "   Cloud Domain:          $CLOUD_DOMAIN"
    echo "   Cloud NTP Server:      $CLOUD_NTP_SERVER"    
    echo "   Cloud DHCP Range:      $CLOUD_DHCP_RANGE"
    echo "   --------------------------------------------------"
    echo 
    echo -n "   Are you sure to continue? [y=yes, r=return, q=quit default:y]: "
    read -n1 ANS
    ANS=${ANS:0:1}
    case ${ANS} in
        Y|y)
        ;;
        R|r)clear;Prompt_Question;Show_Confirm
        ;;
        Q|q)exit 0
        ;;
        *)Show_Confirm
        ;;
    esac
}

Ipcalc() {
:

}

## Check the server hostname is validated
Check_Server_Host_Name(){
#the hostname can be contain "a-zA-Z0-9_-"
if [ -n "`echo $ANS | tr -d 'a-zA-Z0-9_-'`" ]; then
    return 1
else
    return 0
fi
}

## Check the server network address
Check_Server_Network_Address(){
if ! ipcalc -c $ANS >/dev/null 2>&1;then
    return 1
fi
}

## Check the dns address
Check_Server_DNS_Address(){
#value is single
if [ `echo "$ANS" | tr ',|' ' ' | xargs -n 1 | wc -l` -eq 1 ]; then
    if ! ipcalc -c $ANS >/dev/null 2>&1;then
        return 1
    fi
#the value separate by " " or "," or "|"
elif [ `echo "$ANS" | tr ',|' ' ' | xargs -n 1 | wc -l` -gt 1 ]; then
    for i in `echo "$ANS" | tr ',|' ' '`; do
        if ! ipcalc -c $i >/dev/null 2>&1;then
            return 1
        fi
    done   
else
    return 1
fi
}

## Check the cloud domain
Check_Domain(){
#only on area
if [ `echo "$ANS" | xargs -n 1 | wc -l` -ne 1 ]; then
    return 1
fi
#only can contain ".[0-9a-zA-Z]"
if [ -n "`echo "$ANS" | tr -d '.[0-9a-zA-Z]'`" ]; then
    return 1
fi
#the domain shout contain at least "xx.xx"
if ! echo $ANS | grep "[0-9a-zA-Z]\{1,\}\.[0-9a-zA-Z]\{1,\}" >/dev/null 2>&1;then
    return 1
fi
}

## Check the ntp server
Check_NTP_Server(){
if ! echo "$CLOUD_NTP_SERVER" | grep -q "localhost"; then
    ANS="${ANS/localhost/$CLOUD_SERVER_IP}"
fi
#value is single
#if [ `echo "$ANS" | tr ',|' ' ' | xargs -n 1 | wc -l` -eq 1 ]; then
#    if ! ipcalc -c $ANS >/dev/null 2>&1;then
#        return 1
#    fi
##the value separate by " " or "," or "|"
#elif [ `echo "$ANS" | tr ',|' ' ' | xargs -n 1 | wc -l` -gt 1 ]; then
#    for i in `echo "$ANS" | tr ',|' ' '`; do
#        if ! ipcalc -c $i >/dev/null 2>&1;then
#            return 1
#        fi
#    done   
#else
#    return 1
#fi
}

## Check the dhcp range
Check_Dhcp_Range(){
if [ `echo $ANS | awk -F"-" '{print NF}'` -ne 2 ];then
    return 1
fi
DHCP_RANGE_FIRST=`echo $ANS | awk -F"-" '{print $1}'`
DHCP_RANGE_SECOND=`echo $ANS | awk -F"-" '{print $2}'`
if ! ipcalc -c $DHCP_RANGE_FIRST >/dev/null 2>&1;then
    return 1
elif ! ipcalc -c $DHCP_RANGE_SECOND >/dev/null 2>&1;then
    return 1
fi
}

Check_Password(){
[ -z "$ANS" ] && return 1
# the password can only contain "[a-z][A-Z][0-9]~!@#$%^&*()_+-="
if [ -n "`echo $ANS | tr -d '[a-z][A-Z][0-9]~\!@#$%^&*()_+-='`" ]; then
    return 1
else
    return 0
fi
}

## Ask user question
Ask_Question(){
if [ $# -ne 3 ];then
    echo "Function Ask_Question() is error!!"
    exit 100
fi
QUESTION=$1
VARIABLE=$2
ANSWER_CHECK_FUNCTION=$3
FIRST=0
while true;do
    FIRST=$(($FIRST+1))
    echo
    if [ $FIRST -le 1 ]; then
        echo -en "   $QUESTION [default:${!VARIABLE}]: "
    else
        echo -e "   \033[1;32mYour input \"$ANS\" is invalid!\033[0m"
        echo -n "   $QUESTION [default:${!VARIABLE}]: "
    fi    
    read ANS; 
    if [ -n "$ANS" ]; then
        if $ANSWER_CHECK_FUNCTION; then
            eval $VARIABLE=`echo $ANS | tr ' |' ','`
            break
        else
            continue
        fi
    else
        ANS="${!VARIABLE}"
        if $ANSWER_CHECK_FUNCTION; then
            break
        fi
    fi
done
}


## Show the system information
if ! echo $SHOW_SYSTEM_INFORMATION | grep -i n >/dev/null 2>&1; then
    ShowInfo
fi

[ -z "$CLOUD_SERVER_HOSTNAME" ] && CLOUD_SERVER_HOSTNAME=$HOST_NAME
[ -z "$CLOUD_SERVER_IP" ] && CLOUD_SERVER_IP=$IP_ADDRESS
[ -z "$CLOUD_SERVER_IP" ] && CLOUD_SERVER_IP=10.85.138.2
[ -z "$CLOUD_SERVER_NETMASK" ] && CLOUD_SERVER_NETMASK=$IP_NETMASK
[ -z "$CLOUD_SERVER_NETMASK" ] && CLOUD_SERVER_NETMASK=255.255.254.0
[ -z "$CLOUD_SERVER_GATEWAY" ] && CLOUD_SERVER_GATEWAY=$IP_GATEWAY
[ -z "$CLOUD_SERVER_GATEWAY" ] && CLOUD_SERVER_GATEWAY=10.85.138.1
[ -z "$CLOUD_SERVER_DNSSERVER" ] && CLOUD_SERVER_DNSSERVER=$IP_DNS
[ -z "$CLOUD_SERVER_DNSSERVER" ] && CLOUD_SERVER_DNSSERVER=10.85.138.253
[ -z "$CLOUD_NTP_SERVER" ] && CLOUD_NTP_SERVER=localhost
[ -z "$CLOUD_DOMAIN" ] && CLOUD_DOMAIN=$IP_DOMAIN
[ -z "$CLOUD_DOMAIN" ] && CLOUD_DOMAIN=mycloud.cn
    
Prompt_Question(){
## Question: ask for server hostname 
Ask_Question "Please specify ${BOLD}hostname${NORMAL} for this cloud server" CLOUD_SERVER_HOSTNAME Check_Server_Host_Name

## Question: ask for server ip
while true; do
Ask_Question "Please specify ${BOLD}ip address${NORMAL} for this cloud server" CLOUD_SERVER_IP Check_Server_Network_Address
# check this ip address can be used for this network
if [ "$CLOUD_SERVER_IP" != "$IP_ADDRESS" ]; then
    if ping $CLOUD_SERVER_IP -c 1 -w 2 >/dev/null 2>&1; then
        USED_IP_MAC=`arp -a | grep "$CLOUD_SERVER_IP" |awk '{print $((NF-3))}' | sed -n '1p'`
        if [ -n "$USED_IP_MAC" ]; then
            echo -n "   This ip is already used by $USED_IP_MAC, do you want to use anymore? [y/n default:y]: "
        else
            echo -n "   This ip is already used, do you want to use anymore? [y/n default:y]: "
        fi
        read -n1 ANS
        ANS=${ANS:0:1}
        case $ANS in 
            Y|y)break
            ;;
            N|n)continue
            ;;
            *)continue
            ;;
        esac
    else
        break
    fi
else
    break
fi
done

## Question: ask for server netmask
Ask_Question "Please specify ${BOLD}netmask${NORMAL} for this cloud server" CLOUD_SERVER_NETMASK Check_Server_Network_Address

## Question: ask for server gateway
Ask_Question "Please specify ${BOLD}gateway${NORMAL} for this cloud server" CLOUD_SERVER_GATEWAY Check_Server_Network_Address

## Question: ask for dnsserver ip address
Ask_Question "Please specify ${BOLD}dns${NORMAL} for this cloud server(separate by \",\")" CLOUD_SERVER_DNSSERVER Check_Server_DNS_Address

## Question: ask for domain
Ask_Question "Please specify ${BOLD}domain${NORMAL} for the cloud(eg: greatwall.com.cn)" CLOUD_DOMAIN Check_Domain

## Question: ask for cloud ntp server
Ask_Question "Please specify ${BOLD}ntp server${NORMAL} for the cloud" CLOUD_NTP_SERVER Check_NTP_Server

## Question: ask for ssh rsa password
# Ask_Question "Please specify ${BOLD}RSA password between nodes${NORMAL}" CLOUD_RSA_PASSWORD Check_Password

## Question: ask for database password
# Ask_Question "Please specify ${BOLD}database password${NORMAL} for the cloud" CLOUD_DATABASE_PASSWORD Check_Password


#calc the cloud network from the ipaddress & mask
NETWORK_FIRST=`echo $CLOUD_SERVER_IP | cut -d'.' -f1`
NETWORK_SECOND=`echo $CLOUD_SERVER_IP | cut -d'.' -f2`
NETWORK_THIRD=`echo $CLOUD_SERVER_IP | cut -d'.' -f3`
NETWORK_FORTH=`echo $CLOUD_SERVER_IP | cut -d'.' -f4`
MASK_FIRST=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f1`
MASK_SECOND=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f2`
MASK_THIRD=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f3`
MASK_FORTH=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f4`
((NETWORK_FIRST=NETWORK_FIRST&MASK_FIRST))
((NETWORK_SECOND=NETWORK_SECOND&MASK_SECOND))
((NETWORK_THIRD=NETWORK_THIRD&MASK_THIRD))
((NETWORK_FORTH=NETWORK_FORTH&MASK_FORTH))
CLOUD_NETWORK=${NETWORK_FIRST}.${NETWORK_SECOND}.${NETWORK_THIRD}.${NETWORK_FORTH}
CLOUD_DHCP_RANGE_LEFT="${NETWORK_FIRST}.${NETWORK_SECOND}.${NETWORK_THIRD}.$((NETWORK_FORTH+5))"
RANGE_RIGHT=$((NETWORK_FORTH+200))
if [ $RANGE_RIGHT -gt 254 ]; then
    RANGE_RIGHT=254
fi
CLOUD_DHCP_RANGE_RIGHT="${NETWORK_FIRST}.${NETWORK_SECOND}.${NETWORK_THIRD}.${RANGE_RIGHT}"
[ -z "$CLOUD_DHCP_RANGE" ] && CLOUD_DHCP_RANGE="${CLOUD_DHCP_RANGE_LEFT}-${CLOUD_DHCP_RANGE_RIGHT}"

## Question: ask for cloud dhcp range
Ask_Question "Please specify ${BOLD}dhcp range${NORMAL} for the cloud" CLOUD_DHCP_RANGE Check_Dhcp_Range
}

if ! echo $PORMPT_USER_INPUT | grep -i n >/dev/null 2>&1; then
    Prompt_Question
fi

## Show and confirm the user input
if ! echo $SHOW_CONFIRM | grep -i n >/dev/null 2>&1; then
    Show_Confirm
fi

CONFIRM_END_TIME=`date "+%Y-%m-%d %H:%M:%S"`
echo "   1. Collect the system information and user input at $CONFIRM_END_TIME...DONE" >${LOG_DIR}${DEPLOY_LOGNAME}


## Save the variable=value to ${LOG_DIR}${DEPLOY_CONFNAME}
cat <<EOF >${LOG_DIR}${DEPLOY_CONFNAME}
#INSTALL MODE
SERVER_INSTALL_MODE=$SERVER_INSTALL_MODE

#INPUT INFORMATION
CLOUD_SERVER_HOSTNAME=$CLOUD_SERVER_HOSTNAME
CLOUD_SERVER_IP=$CLOUD_SERVER_IP
CLOUD_SERVER_NETMASK=$CLOUD_SERVER_NETMASK
CLOUD_SERVER_GATEWAY=$CLOUD_SERVER_GATEWAY
CLOUD_SERVER_DNSSERVER="$CLOUD_SERVER_DNSSERVER"
CLOUD_DOMAIN=$CLOUD_DOMAIN
CLOUD_DHCP_RANGE=$CLOUD_DHCP_RANGE
CLOUD_NETWORK=$CLOUD_NETWORK
CLOUD_NTP_SERVER="$CLOUD_NTP_SERVER"

##TIME INFORMATION
SCRIPT_START_TIME="$SCRIPT_START_TIME"
CONFIRM_END_TIME="$CONFIRM_END_TIME"

##OS INFORMATION
OS_DISTRIBUTION="$OS_DISTRIBUTION"
OS_FAMILY="$OS_FAMILY"
OS_VERSION=$OS_VERSION
OS_ARCH=$OS_ARCH
OS_HOST_ID=$OS_HOST_ID
NET_ETHER_LIST="$NET_ETHER_LIST"
IP_ADDRESS_ETHER=$IP_ADDRESS_ETHER
IP_ADDRESS_MAC=$IP_ADDRESS_MAC
TIME_ZONE="$TIME_ZONE"

#HARDWARE INFORMATION
SYSTEM_MANUFACTURER="$SYSTEM_MANUFACTURER"
SYSTEM_PRODUCT_NAME="$SYSTEM_PRODUCT_NAME"
SYSTEM_SERIAL_NUMBER="$SYSTEM_SERIAL_NUMBER"
SYSTEM_UUID="$SYSTEM_UUID"
VIRTUAL_CPUS=$VIRTUAL_CPUS
PHYSICAL_CPUS=$PHYSICAL_CPUS
MEMORY_SIZE=$MEMORY_SIZE
MEMORY_FREE=$MEMORY_FREE
DISK_LIST="$DISK_LIST"
DISK_COUNT="$DISK_COUNT"
ROOT_DISK=$ROOT_DISK
ROOT_DISK_SIZE=$ROOT_DISK_SIZE
DISK_SIZE="$DISK_SIZE"

#USER VARIABLE
DVD_FILE_REPO="$DVD_FILE_REPO"
DVD_MOUNT_DIR="$DVD_MOUNT_DIR"
SSH="$SSH"

#SCRIPT INFORMATION
SHOW_SYSTEM_INFORMATION=${SHOW_SYSTEM_INFORMATION:-y}
PORMPT_USER_INPUT=${PORMPT_USER_INPUT:-y}
SHOW_CONFIRM=${SHOW_CONFIRM:-y}
EOF

## Apply the system change
#change the hostname
hostname $CLOUD_SERVER_HOSTNAME
NETWORK_FILE=/etc/sysconfig/network
if grep -q "HOSTNAME" $NETWORK_FILE; then
    sed -i "/HOSTNAME/s/=.*/=$CLOUD_SERVER_HOSTNAME/" $NETWORK_FILE
else
    echo "HOSTNAME=$CLOUD_SERVER_HOSTNAME" >>$NETWORK_FILE
fi
hostname $CLOUD_SERVER_HOSTNAME

#change the ip address(do not take affect immediate)
IFCFG_FILE=/etc/sysconfig/network-scripts/ifcfg-${IP_ADDRESS_ETHER}
# if bonded, change the bond setting

# if not bonded, if ether_num >2. bond the first two ether

sed -i "/NM_CONTROLLED/s/=.*/=no/" $IFCFG_FILE
# ONBOOT
if grep -q "ONBOOT" $IFCFG_FILE; then
    sed -i '/ONBOOT/s/=.*/=yes/' $IFCFG_FILE
else
    sed -i '2s/$/\nONBOOT=yes/' $IFCFG_FILE
fi
# BOOTPROTO
if grep -q "BOOTPROTO" $IFCFG_FILE; then
    sed -i '/BOOTPROTO/s/=.*/=static/' $IFCFG_FILE
else
    sed -i '/ONBOOT/a \BOOTPROTO=static' $IFCFG_FILE
fi
# IPADDR
if grep -q "IPADDR" $IFCFG_FILE; then
    sed -i "/IPADDR/s/=.*/=$CLOUD_SERVER_IP/" $IFCFG_FILE
else
    sed -i "/BOOTPROTO/a \IPADDR=$CLOUD_SERVER_IP" $IFCFG_FILE
fi
# NETMASK
if grep -q "NETMASK" $IFCFG_FILE; then
    sed -i "/NETMASK/s/=.*/=$CLOUD_SERVER_NETMASK/" $IFCFG_FILE
else
    sed -i "/IPADDR/a \NETMASK=$CLOUD_SERVER_NETMASK" $IFCFG_FILE
fi
# GATEWAY
if grep -q "GATEWAY" $IFCFG_FILE; then
    sed -i "/GATEWAY/s/=.*/=$CLOUD_SERVER_GATEWAY/" $IFCFG_FILE
else
    sed -i "/NETMASK/a \GATEWAY=$CLOUD_SERVER_GATEWAY" $IFCFG_FILE
fi


#active an temp ip address
# if the ip is not on this server
if ! ifconfig | grep "$CLOUD_SERVER_IP" >/dev/null 2>&1; then
    if ! ping $CLOUD_SERVER_IP -c 1 -w 2 >/dev/null 2>&1; then
        for i in {1..100}; do
            if ! ifconfig -a | grep "${IP_ADDRESS_ETHER}:${i}" >/dev/null 2>&1; then
                ifconfig ${IP_ADDRESS_ETHER}:${i} $CLOUD_SERVER_IP netmask $CLOUD_SERVER_NETMASK up
                break
            fi
        done
    else
        echo "   The IP address $CLOUD_SERVER_IP seems to be used by other server, exit"
        exit 1
    fi
fi
# change the HOSTS file
HOST_FILE=/etc/hosts
if grep -q "$CLOUD_SERVER_IP" $HOST_FILE; then
    sed -i "/${CLOUD_SERVER_IP}/s/.*/${CLOUD_SERVER_IP}\t${CLOUD_SERVER_HOSTNAME}\t\t${CLOUD_SERVER_HOSTNAME}.${CLOUD_DOMAIN}/" $HOST_FILE
else
    echo -e "${CLOUD_SERVER_IP}\t${CLOUD_SERVER_HOSTNAME}\t\t${CLOUD_SERVER_HOSTNAME}.${CLOUD_DOMAIN}" >>$HOST_FILE
fi
# change the dns & domain
DNS_FILE=/etc/resolv.conf
echo -e "domain\t\t${CLOUD_DOMAIN}" >$DNS_FILE
echo -e "search\t\t${CLOUD_DOMAIN}" >>$DNS_FILE
for i in `echo $CLOUD_SERVER_DNSSERVER | tr ',' ' ' | xargs`; do
    echo -e "nameserver\t${i}" >>$DNS_FILE
done
############################################## change the ntp files ###################################
if [ -f /etc/ntp.conf ]; then
    if [ $CLOUD_NTP_SERVER = "localhost" ]; then
          :
    fi
fi


# No nameservers found; try putting DNS servers into your
# ifcfg files in /etc/sysconfig/network-scripts like so:
#
# DNS1=xxx.xxx.xxx.xxx
# DNS2=xxx.xxx.xxx.xxx
# DOMAIN=lab.foo.com bar.foo.com


DEPLOY_END_TIME=`date "+%Y-%m-%d %H:%M:%S"`
echo >>${LOG_DIR}${DEPLOY_CONFNAME}
echo "#ALREADY DEPLOYED TAG" >>${LOG_DIR}${DEPLOY_CONFNAME}
echo "DEPLOY_END_TIME=\"$DEPLOY_END_TIME\"" >>${LOG_DIR}${DEPLOY_CONFNAME}
echo "DEPLOY_IS_SUCCESSFUL=yes" >>${LOG_DIR}${DEPLOY_CONFNAME}
echo "   2. $SCRIPT_NAME has successful compulete, exec the install.sh at $DEPLOY_END_TIME...DONE" >>${LOG_DIR}${DEPLOY_LOGNAME}

# make a reference file
# touch -t `date "+%Y%m%d%H%M"` ${LOG_DIR}${SCRIPT_NAME}.reference

## start exec the install script
# exec ./install.sh


















## Install the KVM hypervisor(to use the uuid command)

## Change the server network

## Write the hostname to dnsserver config


:<<EOF
SSH_CONF_DIR=${CUR_DIR}configssh/ 
                      


[ ! -d "/.ssh/" ] && mkdir -p /.ssh/

if [ -f ${SSH_CONF_DIR}authorized_keys ];then
    cp -rLf ${SSH_CONF_DIR}authorized_keys /.ssh/
    chmod 600 /.ssh/authorized_keys
else
    echo "   ${SSH_CONF_DIR}authorized_keys not found, exit"
    exit 1
fi


if [ -f ${SSH_CONF_DIR}id_rsa ];then
    cp -rLf ${SSH_CONF_DIR}id_rsa /.ssh/
    chmod 600 /.ssh/id_rsa
else
    echo "   ${SSH_CONF_DIR}id_rsa not found, exit"
    exit 1
fi

if [ -f ${SSH_CONF_DIR}expect.sh ];then
    cp -rLf ${SSH_CONF_DIR}expect.sh /usr/bin/
else
    echo "   ${SSH_CONF_DIR}expect.sh not found, exit"
    exit 1
fi

if [ -f ${SSH_CONF_DIR}configssh.sh ];then
    cp -rLf ${SSH_CONF_DIR}configssh.sh /usr/bin/
    chmod 755 /usr/bin/configssh.sh
fi

if [ -f ${SSH_CONF_DIR}libcrypto_extra.so.0.9.7 ];then
    cp -rLf ${SSH_CONF_DIR}libcrypto_extra.so.0.9.7 /usr/bin/   
fi 
EOF

