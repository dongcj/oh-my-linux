#!/bin/bash
# FileName: cloud_check.sh
## CopyRight  dongchaojun@GreatWall
## Author:dongcj dongcj@greatwall.com.cn
## Usage: cloud_check.sh
## This script is used for check environment before install.
## Modify Log:
    # 2013-1-7: new add.
    #
export LC_ALL=C
## Import the function
if [ -f ./Scripts/cloud_function.sh ]; then
    . ./Scripts/cloud_function.sh
else
    echo "   Please check function file!"
    exit 1
fi


SCRIPT_START_TIME=`date "+%Y-%m-%d %H:%M:%S"`

#################### Check start #################### 
## Echo welcome & waiting
clear
echo;echo;echo;echo
echo "   Welcome to ${FONT_BOLD}${COLOR_GREEN}GreatWall Cloud Auto Installation System${FONT_NORMAL}${COLOR_CLOSE}, please wait..."


## Check the user   
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && Exit


######################################################################
#################### Check the OS , TO BE DONE########################


## Check the hardware
VIRTUAL_CPUS=`cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c | awk '{print $1}'`
PHYSICAL_CPUS=`dmidecode --type processor 2>/dev/null | egrep '^Processor Information$' | wc -l`
# if core 0 has more than one, support HT
#CPU_IF_HT=`if [ $(grep "core id" /proc/cpuinfo | grep -w 0 | wc -l) -lt $(grep "physical id" /proc/cpuinfo  | uniq | wc -l) ]; then echo 1; else echo 0;fi`
# if more than one logical cups have the same core id and physical id, HT support is true.
CPU_CORE=$VIRTUAL_CPUS

_MEMORY_SIZE=`cat /proc/meminfo | grep MemTotal | awk  '{print $2}'`
MEMORY_SIZE=`printf "%G" $(echo "scale = 0; $_MEMORY_SIZE/1000/1000" | bc)`


if [ $CPU_CORE -lt $CLOUD_SERVER_REQUIRE_CPU_CORE ]; then
    Ask_Y_Or_N "Your server cpu is too low(${CPU_CORE}Core, require is ${CLOUD_SERVER_REQUIRE_CPU_CORE}Cores), are you sure to continue?"
fi
if [ $MEMORY_SIZE -lt $CLOUD_SERVER_REQUIRE_MEM_GB ]; then
    Ask_Y_Or_N "Your server memory is too low(${MEMORY_SIZE}GB, require is ${CLOUD_SERVER_REQUIRE_MEM_GB}GB), are you sure to continue?"
fi


## Check the libvirtd & virsh command
lsmod | grep -q kvm || { echo "   KVM module not loaded!"; Exit; }
ps -e | grep -q libvirtd || { echo "   libvirtd not started!"; Exit; }
virsh list >/dev/null 2>&1 || { echo "   virsh command not ready!"; Exit; }
#[ -x /usr/libexec/qemu-kvm ] || { echo "   /usr/libexec/qemu-kvm does not exist!"; Exit; }

## Check the nc & curl & ipcalc command
which qemu-img >/dev/null 2>&1 || { echo "   qemu-img not installed!"; Exit; }
which nc >/dev/null 2>&1 || { echo "   nc not installed!"; Exit; }
which curl >/dev/null 2>&1 || { echo "   curl not installed!"; Exit; }
which ipcalc >/dev/null 2>&1 || { echo "   ipcalc not installed!"; Exit; }


## Check the br0 bridge to eth0
if ! brctl show | grep "$CLOUD_VM_BRIDGE" | grep -q "$CLOUD_VM_BRIDGE_ETHER"; then 
    echo "   The KVM network bridge must be $CLOUD_VM_BRIDGE and bridge to $CLOUD_VM_BRIDGE_ETHER!"
    echo "   Or you can re-define it in ./Scripts/cloud_product.conf"
    Exit
fi


## Config selinux
SELINUX_CONF=/etc/selinux/config
if [ -f $SELINUX_CONF ];then
    CURRENT_SELINUX_VALUE=`awk -F"=" '/^SELINUX=/ {print $2}' $SELINUX_CONF`
    if [ "$CURRENT_SELINUX_VALUE" != "disabled" ];then
        sed -i /^SELINUX=/s/$CURRENT_SELINUX_VALUE/disabled/g $SELINUX_CONF
    fi
fi
setenforce 0 >/dev/null 2>&1



## Config the SSH Service
# UseDNS no
sed -i '/UseDNS/s/.*/UseDNS no/' /etc/ssh/sshd_config
# Use banner
cat <<EOF >/etc/banner
 * * * * * * * * * * * W A R N I N G * * * * * * * * * * * * *
THIS SYSTEM IS RESTRICTED TO AUTHORIZED USERS FOR AUTHORIZED USE
ONLY. UNAUTHORIZED ACCESS IS STRICTLY PROHIBITED AND MAY BE 
PUNISHABLE UNDER THE COMPUTER FRAUD AND ABUSE ACT OF 1986 OR 
OTHER APPLICABLE LAWS. IF NOT AUTHORIZED TO ACCESS THIS SYSTEM,
DISCONNECT NOW. BY CONTINUING, YOU CONSENT TO YOUR KEYSTROKES
AND DATA CONTENT BEING MONITORED. ALL PERSONS ARE HEREBY 
NOTIFIED THAT THE USE OF THIS SYSTEM CONSTITUTES CONSENT TO 
MONITORING AND AUDITING. 
EOF
if ! grep -q GreatWall /etc/banner; then
    echo -e "\t\033[1;32mCloud Management Server by GreatWall\033[0m" >>/etc/banner
    echo >>/etc/banner
fi

sed -i '/Banner/s/.*/Banner \/etc\/banner/' /etc/ssh/sshd_config
 

## Add the OOB IP to br0, if the OOB IP address is already changed, read from cloud.info
#+ ADD OOB IP & Current IP to br0
if [ -n "${CLOUD_SERVER_IP_FOR_CONN_VM}" ] && [ -n "${CLOUD_NETMASK_OOB}" ]; then
    ip addr add ${CLOUD_SERVER_IP_FOR_CONN_VM}/${CLOUD_NETMASK_OOB} dev $CLOUD_VM_BRIDGE >/dev/null 2>&1
    ifconfig $CLOUD_VM_BRIDGE up
else
    echo "   Plese add value to CLOUD_SERVER_IP_FOR_CONN_VM and CLOUD_NETMASK_OOB in $CONF_NAME! "
    Exit
fi

if [ -n "${MY_IP_NEEDED}" ] && [ -n ${NETMASK_CURRENT} ]; then
    ip addr add ${MY_IP_NEEDED}/${NETMASK_CURRENT} dev $CLOUD_VM_BRIDGE >/dev/null 2>&1
    ifconfig $CLOUD_VM_BRIDGE up
fi
    

############### 将此服务器上安装的服务打印出来 ###################
if [ -f ${INFO_DIR}${INFO_NAME} ]; then
    ALL_INST_PRODUCTS=`grep "CLOUD_PRODUCT_IP_SET" ${INFO_DIR}${INFO_NAME} | awk -F"=" '{print $2}' |tr -d '"'`
    if [ -n "$ALL_INST_PRODUCTS" ]; then
        echo 
        echo "   This system has been installed the follow services:"
        $(>/tmp/inst_service.tmp)
        echo -e "   --INST_PRODUCT--\t\t-PRODUCT_IP-\t\t-----INST_TIME-----" >/tmp/inst_service.tmp
        for i in ${ALL_INST_PRODUCTS}; do
            # Get the INST_PRODUCT_NAME
            INST_PRODUCT_NAME=`echo $i | awk -F"," '{print $1}'`
            INST_PRODUCT_IP=`echo $i | awk -F"," '{print $2}'`
            INST_PRODUCT_TIME=`grep "INSTALLATION_TIME" ${INFO_DIR}${INFO_NAME} |  grep "$INST_PRODUCT_NAME" | awk -F"=" '{print $2}' | tr -d '"' | tr " " ","`
            echo -e "   ${INST_PRODUCT_NAME}\t\t${INST_PRODUCT_IP}\t\t${INST_PRODUCT_TIME}\t\t" >>/tmp/inst_service.tmp        
        done
        column -t /tmp/inst_service.tmp | awk '{print "   "$0}'
        rm -rf /tmp/inst_service.tmp
    fi
fi

## 如果本地安装了dns服务器, 定期向DNS



## Exec the cloud_deploy.sh
SCRIPT_END_TIME=`date "+%Y-%m-%d %H:%M:%S"`
echo
echo "   Check passed, please input the information below,"
echo "   $SCRIPT_NAME has successful compulete, exec the cloud_deploy.sh at $SCRIPT_END_TIME...DONE" >>${LOG_DIR}${LOG_NAME}
echo "CHECKED_SUCCESS=yes" >${LOG_DIR}${TRANSIT_CONF}
exec ./cloud_deploy.sh

