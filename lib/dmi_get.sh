#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description: get system and OS information
#

if ! Log &>/dev/null; then  
    Log() { echo "[ $1 ] : $2"; }
    FBS_ESC=`echo -en "\033"`
    COLOR_RED="${FBS_ESC}[1;31m"      
    COLOR_GREEN="${FBS_ESC}[1;32m";    
    COLOR_YELLOW="${FBS_ESC}[1;33m"    
    COLOR_CLOSE="${FBS_ESC}[0m" 
    Run() { echo $*; $*; }
fi

######################################################################
# 作用: 判断 OS 发行版
# 用法: Check_OS_Distrib 
# 注意：
######################################################################
Check_OS_Distrib(){

   RELEASE_FILE=/etc/*-release
   if grep -Eqi "CentOS" /etc/issue &>/dev/null || \
   grep -Eq "CentOS" $RELEASE_FILE &>/dev/null; then
       OS=CentOS
       PKG_INST_CMD="yum -y install"
       RELEASE_FILE=/etc/centos-release
       
   elif grep -Eqi "Debian" /etc/issue  &>/dev/null || \
   grep -Eq "Debian" $RELEASE_FILE &>/dev/null; then
       OS=Debian
       PKG_INST_CMD="apt -y install"
       RELEASE_FILE=/etc/lsb-release
       
   elif grep -Eqi "Ubuntu" /etc/issue  &>/dev/null || \
   grep -Eq "Ubuntu" $RELEASE_FILE &>/dev/null; then
       OS=Ubuntu
       PKG_INST_CMD="apt -y install"
       RELEASE_FILE=/etc/lsb-release
       
   elif grep -Eqi "Alpine" /etc/issue  &>/dev/null || \
   grep -Eq "Alpine" $RELEASE_FILE &>/dev/null; then
       OS=Alpine
       PKG_INST_CMD="apk -y -q install"
       RELEASE_FILE=/etc/lsb-release
        
   else
       echo "Not support OS, Please reinstall OS and retry!"
       exit 1
   fi
}

######################################################################
# 作用: 为服务器安装所需要的基础软件
# 用法: Install_Basic_Soft
# 注意：依赖 Check_OS_DISTRIB
######################################################################
Install_Basic_Soft() {

    Log DEBUG "${COLOR_YELLOW}Installing basic software...${COLOR_CLOSE}"
    
    # basic software 
    if  bc -v &>/dev/null && lsscsi &>/dev/null; then
        Log DEBUG "${COLOR_YELLOW}Already installed, continue...${COLOR_CLOSE}"
        return
    fi
    
    softlist_basic="bc ethtool lsscsi net-tools smartmontools wget"
    softlist_basic=`echo $softlist_basic`
    
    softlist_recommand="bash-completion bmon fio  hdparm  htop \
    ipmitool iotop ifstat locales  mycli nmon ntp \
    pciutils python-pip  rsync"
    softlist_recommand=`echo $softlist_recommand`

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
    
    Run $PKG_INST_CMD $softlist_basic
    Run $softlist_recommand $softlist_recommand
    
    # if the has pci raid
    pci_info=`lspci`
    if echo "$pci_info" | grep -i raid | grep -iq mega; then
        Run $PKG_INST_CMD -y -q install MegaCli

    elif echo "$pci_info" | grep -i raid | grep -iq hewlett; then
        Run $PKG_INST_CMD -y -q install hpacucli
    fi
    
    Log SUCC "Install basic software successful."
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
    SYSTEM_RACKHEIGHT=`dmidecode | grep 'Height: ' | awk -F':' '{print $2}' | xargs`
    SYSTEM_BASEBOARD=`dmidecode -t baseboard | grep 'Manufacturer: ' | awk '{print $2}'`
    SYSTEM_BASEBOARDNAME=`dmidecode -t baseboard | grep 'Product Name: ' | awk -F':' '{print $NF}' | xargs`
    SYSTEM_UUID=`echo "$DMIDECODE" | grep 'UUID' | head -n 1 | cut -f 2 -d':' | xargs`
    
    
    Log DEBUG " --SYSTEM_MANUFACTURER=\"$SYSTEM_MANUFACTURER\""
    Log DEBUG " --SYSTEM_PRODUCTNAME=\"$SYSTEM_PRODUCTNAME\""
    Log DEBUG " --SYSTEM_RACKHEIGHT=\"$SYSTEM_RACKHEIGHT\""
    Log DEBUG " --SYSTEM_SERIALNUMBER=\"$SYSTEM_SERIALNUMBER\""
    Log DEBUG " --SYSTEM_BASEBOARD=\"$SYSTEM_BASEBOARD\""
    Log DEBUG " --SYSTEM_BASEBOARDNAME=\"$SYSTEM_BASEBOARDNAME\""
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
    OS_VERSION=`grep ${OS_DISTRIBUTION} $RELEASE_FILE | sed -n '$p' | \
      awk -F'[ "=]' '{ i=1; while(i<NF) { if ( $i~/[0-9]\.[0-9]/ ) print $i; i++ }}'`
    OS_ARCH=`arch`;OS_BIT=`getconf LONG_BIT`
    OS_HOSTID=`hostid`
    OS_HOSTNAME=${MY_HOSTNAME:-$HOSTNAME}

    Log DEBUG " --OS_FAMILY=$OS_FAMILY"
    Log DEBUG " --OS_DISTRIBUTION=\"$OS_DISTRIBUTION\""
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
    CPU_SPEEDCURRENT=`grep 'cpu MHz' /proc/cpuinfo | sort | sed -n '$p' | awk '{printf "%d", $NF}'`
    CPU_FAMILY=`if grep AuthenticAMD /proc/cpuinfo >/dev/null; then echo AMD; elif grep \
                Intel /proc/cpuinfo >/dev/null; then echo Intel; else echo Unknown; fi`
    CPU_MODELNAME=`grep "model name" /proc/cpuinfo | uniq | awk -F":" '{print $2}' | sed 's/           / /' | xargs`

    Log DEBUG " --CPU_PHYSICAL=$CPU_PHYSICAL"
    Log DEBUG " --CPU_IFHT=$CPU_IFHT"
    Log DEBUG " --CPU_CORE=$CPU_CORE"
    Log DEBUG " --CPU_THREAD=$CPU_THREAD"
    Log DEBUG " --CPU_SPEEDCURRENT=$CPU_SPEEDCURRENT"
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
    MEMORY_TOTAL=`printf "%G" $(echo "scale = 1; $_MEMORY_TOTAL/1024/1002" | bc)`
    
    _MEMORY_FREE=`echo "$MEM_INFO" | grep MemFree | awk  '{print $2}'`
    MEMORY_FREE=`printf "%G" $(echo "scale = 1; $_MEMORY_FREE/1024/1002" | bc)`
    
    MEMORY_INFO=`dmidecode --type 17`
    MEMORY_SLOT=`echo "$MEMORY_INFO" | grep "Memory Device" | wc -l`
    
    MEMORY_TYPE=`echo "$MEMORY_INFO" | grep "Type: " | awk '{print $2}' | sort | uniq`
    MEMORY_SLOTUSED=`echo "$MEMORY_INFO" | grep "Size" | grep -v "No Module Installed" | wc -l`
    
    # memory speed 
    MEMORY_SPEED=`echo "$MEMORY_INFO" | grep " *Speed: " | grep -v Clock | \
    sed -n 's/.*Speed: \(.*\) [MHz|MT].*/\1/p' | sort | uniq`
    
    MEMORY_SPEED=${MEMORY_SPEED:-"Unknown"}
    
    MEMORY_SPEEDCONFIGURED=`echo "$MEMORY_INFO" | grep " *Speed: " | egrep "MHz|MT" | \
    sed -n 's/.*Speed: \(.*\) [MHz|MT].*/\1/p' | sort | uniq`
    MEMORY_SPEEDCONFIGURED=${MEMORY_SPEEDCONFIGURED:-"Unknown"}
    
    MEMORY_MANUFACTURER=`echo "$MEMORY_INFO" | sed -n 's/.*Manufacturer: \(.*\)/\1/p' | \
    egrep -v "Manufacturer|BAD INDEX" | sort | uniq | xargs`
    
    MEMORY_SERIALNUMBER=`echo "$MEMORY_INFO" | sed -n 's/.*Serial Number: \(.*\)/\1/p' | \
    egrep -v "SerNum|BAD INDEX" | sort | uniq | xargs`
    
    Log DEBUG " --MEMORY_TOTAL=${MEMORY_TOTAL} GB"
    Log DEBUG " --MEMORY_FREE=${MEMORY_FREE} GB"
    Log DEBUG " --MEMORY_SLOT=$MEMORY_SLOT"
    Log DEBUG " --MEMORY_SLOTUSED=$MEMORY_SLOTUSED"
    Log DEBUG " --MEMORY_TYPE=$MEMORY_TYPE"
    Log DEBUG " --MEMORY_SPEED=$MEMORY_SPEED"
    Log DEBUG " --MEMORY_SPEEDCONFIGURED=$MEMORY_SPEEDCONFIGURED"
    Log DEBUG " --MEMORY_MANUFACTURER=\"$MEMORY_MANUFACTURER\""
    Log DEBUG " --MEMORY_SERIALNUMBER=\"$MEMORY_SERIALNUMBER\""
    
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
    DISK_PATH=`echo "$DISK_LIST" | xargs -n1  | sed 's/^/\/dev\//' | xargs`
    
    DISK_COUNT=`echo ${DISK_LIST} | wc -w | xargs`

    # root disk
    DISK_ROOTTYPE=`echo "$blkinfo" | grep -w "part /" | awk '{print $(NF-1)}'`

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

        # check if disk in raid(1 in raid, 0 not in raid)
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
        
        # is vm?
        if echo $DISK_PATH | grep -q "/dev/vd[a-z]"; then
            Log WARN " --disk_path contain \"vd\", might be a vm"
        else
            
            for i in $DISK_PATH; do
                # test disk info
                disk_info=`smartctl -i $i`

                # get the disk Rotation Rate
                disk_rotation_rate=`echo "$disk_info" | grep "Rotation Rate" | awk -F':' '{print $2}'`
                
                if echo $disk_rotation_rate | grep -q "Solid State Device"; then
                    disk_rotation_rate="SSD"
                else
                    disk_rotation_rate=`echo $disk_rotation_rate`
                fi
                [ -z "$disk_rotation_rate" ] && disk_rotation_rate="Unknown"

                # get disk rotation rate
                DISK_ROTATION_RATE_LIST="${DISK_ROTATION_RATE_LIST} ${i}:'${disk_rotation_rate}'"
            done
        fi
            
    else
        while read line; do

            disk_path=`echo $line | awk '{print $NF}'`
            raidcard_brand=`echo $line | awk '{print $3}'`
            
            # if is ATA
            if [ "$raidcard_brand" = "ATA" ]; then

                Log DEBUG " --$disk_path is JBOD mode"

                # test disk info
                disk_info=`smartctl -i $disk_path`

                # get the disk Rotation Rate
                disk_rotation_rate=`echo "$disk_info" | grep "Rotation Rate" | awk -F':' '{print $2}'`
                if echo $disk_rotation_rate | grep -q "Solid State Device"; then
                    disk_rotation_rate="SSD"
                else
                    disk_rotation_rate=`echo $disk_rotation_rate`
                fi
                [ -z "$disk_rotation_rate" ] && disk_rotation_rate="Unknown"

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
                if echo $disk_rotation_rate | grep -q "Solid State Device"; then
                    disk_rotation_rate="SSD"
                else
                    disk_rotation_rate=`echo $disk_rotation_rate`
                fi
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
        if echo $DISK_ROTATION_RATE_LIST | sed "s/' /'\n/g" | grep -w $i | grep -q "SSD"; then
            DISK_SSD="$DISK_SSD $i"

        else
            DISK_SATA="$DISK_SATA $i"

        fi
    done


    DISK_SATA=`echo $DISK_SATA`
    DISK_SSD=`echo $DISK_SSD`

    Log DEBUG " --DISK_LIST=\"$DISK_LIST\""
    Log DEBUG " --DISK_PATH=\"$DISK_PATH\""
    Log DEBUG " --DISK_SIZE=\"$DISK_SIZE\""
    Log DEBUG " --DISK_COUNT=$DISK_COUNT"
    Log DEBUG " --DISK_ROOT=$DISK_ROOT"
    Log DEBUG " --DISK_BOOT=$DISK_BOOT"
    Log DEBUG " --DISK_ROOTTYPE=\"$DISK_ROOTTYPE\""
    Log DEBUG " --DISK_INLVM_RAID=\"$DISK_INLVM_RAID\""
    Log DEBUG " --DISK_ROOTSIZE=\"${DISK_ROOTSIZE} GB\""
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

    Log DEBUG "${COLOR_YELLOW}Getting Network info...${COLOR_CLOSE}"

    NETWORK_PCI_INFO=`lspci | grep "Ethernet controller"`
    NETWORK_PCIETHER_COUNT=`echo "$NETWORK_PCI_INFO" | wc -l`
    
    if echo $NETWORK_PCI_INFO | grep -q Virtio; then
        Log WARN "Virtio network device found, might be a vm"
        NETWORK_PCIETHER_1G_BRAND=virtio
        NETWORK_PCIETHER_10G_BRAND=virtio
    fi

    NETWORK_PCIETHER_1G_COUNT=`echo "$NETWORK_PCI_INFO" | grep " Gigabit " | wc -l`
    
    if [ "$NETWORK_PCIETHER_1G_COUNT" -gt 0 ] && [ -z "$NETWORK_PCIETHER_1G_BRAND" ]; then
        NETWORK_PCIETHER_1G_BRAND=`echo "$NETWORK_PCI_INFO" | grep " Gigabit " | \
        sed  "s/.* Ethernet controller: \(.*\) Gigabit .*/\1/" | sort | uniq`
    fi
    
    NETWORK_PCIETHER_10G_COUNT=`echo "$NETWORK_PCI_INFO" | grep " 10-Gigabit " | wc -l`
    
    if [ "$NETWORK_PCIETHER_10G_COUNT" -gt 0 ] && [ -z "$NETWORK_PCIETHER_10G_BRAND" ]; then
        NETWORK_PCIETHER_10G_BRAND=`echo "$NETWORK_PCI_INFO" | grep " 10-Gigabit " | \
        sed "s/.*Ethernet controller: \(.*\) 10-Gigabit .*/\1/" | sort | uniq`
    fi
    
    NETWORK_ALLETHERS=`ip a | egrep '^[0-9]*:' | awk '{ print $2 }' | grep -v lo | \
    grep -v veth | tr -d ':' | xargs`

    # get the physical ether
    unset NETWORK_PHYETHERS
    for i in $NETWORK_ALLETHERS; do
        if ethtool $i 2>/dev/null | grep "Supported ports" | egrep -q "FIBRE|TP"; then
            NETWORK_PHYETHERS="$NETWORK_PHYETHERS $i"
        fi
    done
    NETWORK_PHYETHERS=`echo $NETWORK_PHYETHERS`

    NETWORK_PHYETHERS_COUNT=`echo $NETWORK_PHYETHERS | wc -w`

    [ $NETWORK_PCIETHER_COUNT -ne $NETWORK_PHYETHERS_COUNT ] && \
    Log WARN "NETWORK_PCIETHER_COUNT=$NETWORK_PCIETHER_COUNT; NETWORK_PHYETHERS_COUNT=$NETWORK_PHYETHERS_COUNT. might be a vm"


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
    NET_USE_ETHER=`ip route get 8.8.8.8 | grep src | sed "s/.* dev \(.*\) src .*/\1/"`
    
    # get the NET_USE_ETHER type(only support bridge or bond now, other mode not support)
    if ! echo $NETWORK_PHYETHERS | grep -wq $NET_USE_ETHER; then

        # if linux bridge
        if ! brctl show $NET_USE_ETHER 2>/dev/null | grep -q "Operation not supported"; then
            NET_USE_ETHER_TYPE=bridge

        # if linux bond
        elif cat /proc/net/bonding/* | grep -q $NET_USE_ETHER; then
            NET_USE_ETHER_TYPE=bond

        else
            NET_USE_ETHER_TYPE=Unknown

        fi

    else
        NET_USE_ETHER_TYPE=raw

    fi

     NETWORK_IPADDR=`ip a show $NET_USE_ETHER | grep "inet " | \
     awk '{print $2}' | head -1 | xargs`

    # Other ip get method
    # ip addr show eth0|awk '/inet /{split($2,x,"/");print x[1]}'
    # ifconfig eth0| awk '{if ( $1 == "inet" && $3 ~ /^Bcast/) print $2}' | awk -F: '{print $2}'
    # ifconfig -a|grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'|head -1
    # ifconfig -a|perl -e '{while(<>){if(/inet (?:addr:)?([\d\.]+)/i){print $1,"\n";last;}}}'


    # Another way to get ip address is:
    #IP_ADDRESS=`ip addr show eth0 | awk '/inet /{split($2,x,"/");print x[1]}'`
    
    if [ -f /etc/network/interfaces ]; then
        NETWORK_GATEWAY=`grep -i "^ *gateway" /etc/network/interfaces | awk '{print $2}' | sed -n '1p'`
     elif [ -f /etc/sysconfig/network-scripts/ifcfg-$NET_USE_ETHER ]; then
        NETWORK_GATEWAY=`grep "^ *GATEWAY=" /etc/sysconfig/network-scripts/ifcfg-$NET_USE_ETHER | \
          awk -F"=" '{print $2}' | sed -n '1p'`
     fi
     
    [ -z "$NETWORK_GATEWAY" ] && NETWORK_GATEWAY=`netstat -rn | grep "UG" |grep "^0.0.0.0" | sed -n '1p' | awk '{print $2}'` && \
    Log WARN "can NOT find \"GATEWAY\", current GATEWAY=$NETWORK_GATEWAY, mybe use DHCP."

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
    Log DEBUG " --NETWORK_IPADDR=\"$NETWORK_IPADDR\""
    Log DEBUG " --NETWORK_GATEWAY=$NETWORK_GATEWAY"
    Log DEBUG " --NETWORK_DNS=$NETWORK_DNS"
    Log DEBUG " --NETWORK_DOMAIN=$NETWORK_DOMAIN"

    Log SUCC "Get Network info successful."

}


if [ "$SHLVL" -le 2 ]; then

    # assum use directly from command, not inital by other scripts
    Check_OS_Distrib
    Install_Basic_Soft
    Get_SystemInfo
    Get_OSInfo
    Get_CPUInfo
    Get_MEMInfo
    Get_DiskInfo
    Get_NetInfo
fi
