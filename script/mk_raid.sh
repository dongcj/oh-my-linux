#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description: 自动或根据用户配置自动做指定级别的软/硬raid
# Usage:  mk_raid.sh [ --raid_disk='/dev/sda /dev/sdb' --spare_disk='/dev/sdc' --raid_level=10 ]

#################################################################
## 1. User Config
#################################################################
# 指定需要做raid的磁盘
# 指定格式如: RAID_DISK="sdb  sdc  sdd  sde"
RAID_DISK=""


# 指定热备盘, 不指定也可以, 但在需要高度可用性的场景, 建议使用
SPARE_DISK=""


# 指定raid级别, 如果不指定，会自动根据磁盘进行判断使用的raid; 
# +如指定，会自动判断指定的raid是否符合磁盘要求
# 0, 1, 5, 10, 50
RAID_LEVEL=""



# 指定日志路径
LOG_FILE="/tmp/mk_SoftRaid.log"


# filesystem option
FSTYPE=xfs


# ceph osd make filesystem option
MKFS_OPTION="-f -i size=2048"


# mount point
FS_MOUNT_POINT="/mnt/"


# ceph osd filesystem type mount option
FS_MOUNT_OPTION="rw,noatime,nodiratime,attr2,inode64,nobarrier,logbsize=256k,logbufs=8,allocsize=4m"




#################################################################
## 2. ENV setting
#################################################################
NOW_TIME='eval date "+%Y-%m-%d %H:%M:%S"'
[ -d $FS_MOUNT_POINT ] || mkdir -p $FS_MOUNT_POINT

## Terminal Style
set -o ignoreeof
TERM=xterm; export TERM;

[[ "$LANGUAGE" = "cn" ]] && export LANG=en_US.UTF-8  || export LANG=C


## Colorful
FBS_ESC=`echo -en "\033"`
COLOR_RED="${FBS_ESC}[1;31m"       # Error
COLOR_GREEN="${FBS_ESC}[1;32m";    # Success
COLOR_YELLOW="${FBS_ESC}[1;33m"    # Warning
COLOR_CLOSE="${FBS_ESC}[0m"        # Close

CURSOROFF=`echo -e "\033[?25l"`
CURSORON=`echo -e "\033[?25h"`
OLD_STTY_SETTING=$(/bin/stty -g)




#################################################################
## 3. Functions
#################################################################


######################################################################
# 作用: echo & log to file
# 用法: Log <LOG_LEVEL> <LOG_INFO_MSG>
# 注意：
######################################################################
Log() { 

    if [ $# -ne 2 ];then
        Log ERROR "Function Log() error! Usage: Log <LOG_LEVEL> <LOG_INFO_MSG>\n"
    fi
    
    local level="$1"
    local info="$2"
    
    # 根据不同级别显示不同的颜色
    case $level in
        DEBUG)
            printf "  [$level]: $info\n";

            # log to file
            echo -e "`$NOW_TIME`\t[$level]\t$info" &>>${LOG_FILE}    
        ;;
        WARN)
            
            printf "  ${COLOR_YELLOW}[$level ]: [!]$info${COLOR_CLOSE}\n"; 
            echo -e "`$NOW_TIME`\t[$level]\t$info" &>>${LOG_FILE} 
        ;;
        ERROR)
            printf "  ${COLOR_RED}[$level]: [X] $info${COLOR_CLOSE}\n"; 
            echo -e "`$NOW_TIME`\t[$level]\t$info" &>>${LOG_FILE} 
            
            exit 1
        ;;
        SUCC)

            printf "  ${COLOR_GREEN}[$level ]: [√]$info${COLOR_CLOSE}\n\n"; 
            echo -e "`$NOW_TIME`\t[$level]\t$info" &>>${LOG_FILE} 
        ;;

        *)
            echo -e "  Function Log() error! Usage: Log [LEVEL] <INFORMATION>\n"
            exit 250
        ;;
    esac


}


######################################################################
# 作用: 捕捉用户的中断,即用ctrl+C中断时提示用户,防止误退出
# 用法: 无须使用 
# 注意: 无须在各个脚本中调用了，这里已调用了
######################################################################
trap TrapProcess 2 3
TrapProcess() {
    clear
    echo
    echo
    echo -e "\033[?25h"
    /bin/stty -igncr
    /bin/stty echo
    tput cup `expr $(tput lines) / 2 - 1` `expr $(tput cols) / 2 - 50`
    echo -n "      Do you really want to quit? \"n\" or \"c\"  to continue, \"y\" or \"q\" to quit : "
    read -n1 ANS
    if [ "${ANS}" = "Y" -o "${ANS}" = "y" -o "${ANS}" = "Q" -o "${ANS}" = "q" ];then
        clear
        Log ERROR "Exit by user!"
    else
        return 0
    fi
}


######################################################################
# 作用: y继续，n退出
# 用法: Ask_Y_Or_N <QUESTION>
# 注意：
######################################################################
Ask_Y_Or_N(){
if [ $# -ne 1 ];then
    echo "Function Ask_Y_Or_N() is error!!"
    exit 100
else
    QUESTION=$1
    while true;do
        echo
        echo -en "  ${QUESTION} [Y/N]: "
        read ANS 
        case ${ANS} in
            N|n)exit 0;
            ;;
            Y|y|"")echo;echo;break;
            ;;
            *)echo "  ${COLOR_RED}Incorrect choice!!${COLOR_CLOSE}";continue;
        esac
    done
fi
}


######################################################################
# 作用: install software
# 用法: Log <LOG_LEVEL> <LOG_INFO_MSG>
# 注意：
######################################################################
Install_Basic_Soft() {

    # smartmontools: to use smartctl
    # pciutils: to use lspci
    softlist="  pciutils  lsscsi  smartmontools   "
    
    softlist=`echo $softlist`
    Run yum -y -q install $softlist
    
    
    # if the has pci raid
    pci_info=`lspci`
    if echo "$pci_info" | grep -i raid | grep -iq mega; then
        Run yum -y -q install MegaCli
    
    elif echo "$pci_info" | grep -i raid | grep -iq hewlett; then
        Run yum -y -q install hpacucli
    fi
    
}


######################################################################
# 作用: 检查磁盘情况
# 用法: Get_Disk_Info
# 注意：
######################################################################
Get_Disk_Info(){

    Log DEBUG "Get DISK info..."
    
    # formated lsblk
    blkinfo=`lsblk | sed '/disk/{x;p;x;}' | sed -n '1!p'`
    
    # if there are mutlipath
    if echo "$blkinfo" | grep -q mpath; then
        dmsetup remove_all
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
    
    
    DISK_ROTATION_RATE_LIST=`echo $DISK_ROTATION_RATE_LIST`
        
    [ -z "$DISK_ROTATION_RATE_LIST" ] && Log ERROR "can NOT get the disk rotation rate info!!"    
    
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
    Log DEBUG ""
    
}






######################################################################
# 作用: Check_Disk
# 用法: Check_Disk
# 注意：
######################################################################
Check_Disk() {

    
    # if has hard raid
    if [ "$DISK_RAIDCARD" != "$none" ]; then

    
        # if disk already in hard raid
        #alreay in 
        #if [ `echo $DISK_ISINRAID` ]
    
    
        :
    
    
    
    
    # if no, use 

    
    

    fi
}



    

######################################################################
# 作用: 解析参数, 优先级: 此脚本中配置 > 参数
# 用法: Arg_Parser
# 注意：
######################################################################
Arg_Parser() {

    ## arg parse
    arg_raid_disk=`echo ${*} | sed 's/\-\{1,2\}/\n/g' | grep raid_disk | awk -F'=' ' {print $2}'`
    arg_spare_disk=`echo ${*} | sed 's/\-\{1,2\}/\n/g' | grep spare_disk | awk -F'=' ' {print $2}'`
    arg_raid_level=`echo ${*} | sed 's/\-\{1,2\}/\n/g' | grep raid_level | awk -F'=' ' {print $2}'`

    RAID_DISK=${RAID_DISK:-$arg_raid_disk}
    SPARE_DISK=${RAID_DISK:-$arg_spare_disk}
    RAID_LEVEL=${RAID_DISK:-$arg_raid_level}
    
    
    
}




######################################################################
# 作用: 如果用户未输入参数或未配置，用户使用选项进行选择
# 用法: Prompt_For_Disk
# 注意：
######################################################################
Prompt_For_Disk() {

    ## arg parse
    
    
    
}





######################################################################
# 作用: make soft raid
# 用法: Make_SoftRaid  <RAID_DISKS> <RAID_LEVEL> [SPAR_DISKS]
# 注意：
######################################################################
Make_SoftRaid() {

    mdadm --create /dev/md0 -v --raid-devices=6 --level=raid10 /dev/sda1 /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1
}




######################################################################
# 作用: make hard raid
# 用法: Make_HardRaid  <RAID_DISKS> <RAID_LEVEL> [SPAR_DISKS]
# 注意：
######################################################################
Make_HardRaid() {

    :
}




######################################################################
# 作用: make filesystem and auto mount
# 用法: MakeFS_And_AutoMount
# 注意：
######################################################################
MakeFS_And_AutoMount() {


    :

}


######################################################################
# 作用: make filesystem and auto mount
# 用法: Destory_Raid  <RAID_DEVICE]
# 注意：
######################################################################
Destory_Raid() {

    # check raid status
    
    Ask_Y_Or_N "Continue will cause ${COLOR_RED}DATA LOSE${COLOR_CLOSE}, do you realy want to continue?"

    
    # ### 停止并移除阵列
    # mdadm --stop /dev/md99
    # mdadm --remove /dev/md99


    # ### 销毁系统中的阵列
    # mdadm --manage /dev/md99 --fail /dev/sd[cde]1
    # mdadm --manage /dev/md99 --remove /dev/sd[cde]1
    # mdadm --manage /dev/md99 --stop
    # mdadm --zero-superblock /dev/sd[cde]1


}


#################################################################
## 4. Main
#################################################################

# parse argument
Arg_Parser_Or_Pormpt


# get the disk info
Get_Disk_Info


# get the disk info
Check_Disk




## make raid
# if has hard raid, prompt to select

