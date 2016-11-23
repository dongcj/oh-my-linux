#!/bin/bash
#用于格式化除了系统盘以外的所有分区，如/dev/sdb、/dev/sdc等
#参数说明：
#用法：disk_part "$disklist" "disklist_journal" 'ext4|xfs|btrfs' '{0..4}' '-f -i size=2048'  '2136997888' \
                 'defaults,noatime' 'admin:admin' '20' 'shared|standalone'
                 
Disk_Part_Format_Mount(){

    disklist=$1
    disklist_journal=$2
    fstype=$3
    osd_number=$4
    mkfs_option=$5
    mkfs_logdev_size=$6
    mount_option=$7
    diskuser=$8
    journal_size=$9
    mode=${10}
    
    osd_number_begin=`echo $osd_number | awk -F'-' '{print $1}'`
    osd_number_end=`echo $osd_number | awk -F'-' '{print $2}'`
    osd_total_num=`expr $osd_number_end - $osd_number_begin + 1`
    part_no=1
    
    # Making directory for ceph
    ceph_osd_dir_prefix="/var/lib/ceph/osd/${CEPH_CLUSTERNAME}-"
    for ((i=$osd_number_begin; i<=$osd_number_end; i++)); do
        mkdir -p ${ceph_osd_dir_prefix}${i}
        chown -R $diskuser ${ceph_osd_dir_prefix}${i}
    done
    

    Log DEBUG "starting partition disk $disklist"

    # install mkfs prog
    if [ "$fstype" = "ext4" ]; then
        which mkfs.ext4 >&/dev/null || { yum -y install e2fsprogs && Log DEBUG "install e2fsprogs success"; }
    elif [ "$fstype" = "xfs" ]; then
        which mkfs.xfs >&/dev/null || { yum -y install xfsprogs && Log DEBUG "install xfsprogs"; }
    elif [ "$fstype" = "btrfs" ]; then
        which mkfs.btrfs >&/dev/null || { yum -y install btrfs-progs; Log DEBUG "install btrfs-progs" ;}
    else
        Log ERROR "fstype not support"
    fi    
    
    # gpt fit for every disk
    label_type='gpt'
    
    myPARTITIONDEV="${TMP_DIR}/auto-partition.dev"
    myPARTITIONPID="${TMP_DIR}/auto-partition.pid"
    cat /dev/null > ${myPARTITIONDEV}
    cat /dev/null > ${myPARTITIONPID}
    
    # first destory the logdev
    for device in $disklist_journal; do
        Run parted -s $device mklabel $label_type
    done
    Log DEBUG ""
    
    
    for device in $disklist;do
    
        if echo $device | grep -q 'cciss' ; then
            Log WARN "$device is a cciss device"
            part1=p1
            part2=p2
        else
            part1=1
            part2=2
        fi
    
        # remove part
        partnumber=`parted -s $device print 2>/dev/null  | sed  -n '/Number/,/$$/p' | sed -n '1!p' | awk '{print $1}' | xargs`
        for i in $partnumber; do
           Run parted -s $device rm $i &>/dev/null
        done


        # get the disk size & set label type(always use gpt)
                
        total_size=`lsblk $device | grep disk | awk '{print $4}'`
        if echo $total_size | grep -q "G"; then
            total_size=`echo $total_size | sed 's/G//'`
        elif echo $total_size | grep -q "T"; then
            total_size=`echo $total_size | sed 's/T//'`
            let total_size="$total_size*1024"
        else
            Log ERROR "do not recognize the disk $device capacity"
        fi
        
        # calc the percent of journal_size
        data_percent=`echo "scale = 2; 1 - $journal_size / $total_size" | bc | tr -d '^.'`
        data_percent=$((10#${data_percent}))
        
        Log DEBUG "device $device really total_size=$total_size, data_percent=$data_percent"
        
        # parted data disk(osd-device-<num>-data, osd-device-<num>-journal)
        if [ "$mode" = "shared" ]; then
            Run parted -s $device mklabel $label_type
            
            Run parted -s $device mkpart osd-device-${osd_number_begin}-data 0% ${data_percent}%
            
            Run parted -s $device mkpart osd-device-${osd_number_begin}-journal ${data_percent}% 100%
            
            # LABEL(use: fsblk -f)
            # if [ "$fstype" = "ext4" ]; then
                # Run e2label ${device}${part1} "data-${osd_number_begin}"
                # Run e2label ${device}${part2} "journal-${osd_number_begin}"
                
            # elif [ "$fstype" = "xfs" ]; then
                # Run xfs_admin -L data-${osd_number_begin}    ${device}${part1}
                # Run xfs_admin -L journal-${osd_number_begin} ${device}${part2}
                
            # elif [ "$fstype" = "btrfs" ]; then
                # Run btrfs filesystem label ${device}${part1} data-${osd_number_begin}
                # Run btrfs filesystem label ${device}${part2} journal-${osd_number_begin}
            # else
                # Log ERROR "fstype not support"
            # fi   
            
            partprobe $device &>/dev/null
        elif [ "$mode" = "standalone" ]; then
            Run parted -s $device mklabel $label_type
            
            # mkpart will cause mount?
            Run parted -s $device mkpart osd-device-${osd_number_begin}-data 0% 100%
            
            # LABEL(use: fsblk -f)
            # if [ "$fstype" = "ext4" ]; then
                # Run e2label ${device}${part1} data-${osd_number_begin}
            # elif [ "$fstype" = "xfs" ]; then
                # Run xfs_admin -L data-${osd_number_begin} ${device}${part1}
            # elif [ "$fstype" = "btrfs" ]; then
                # Run btrfs filesystem label ${device}${part1} data-${osd_number_begin}
            # else
                # Log ERROR "fstype not support"
            # fi   
            
            partprobe $device &>/dev/null
        else
            Log ERROR "only support disk mode: shared or standalone. please concat system administrator"
        fi
        sleep 2
        Log SUCC "device $device parted complete"
        


        
        # format: datadev logdev mount_num_id
        if [ "$mode" = "shared" ]; then
            echo "${device}${part1} ${device}${part2} $osd_number_begin" >> ${myPARTITIONDEV}
        elif [ "$mode" = "standalone" ]; then
            echo "${device}${part1} ${disklist_journal}${part_no} $osd_number_begin" >> ${myPARTITIONDEV}
        fi
        
        
        osd_number_begin=`expr $osd_number_begin + 1`
        part_no=`expr $part_no + 1`
        Log DEBUG ""
        
    done
    
    
    # journal partition
    # re-get value
    osd_number_begin=`echo $osd_number | awk -F'-' '{print $1}'`
    osd_number_end=`echo $osd_number | awk -F'-' '{print $2}'`
    
    # single journal disk format
    if [ "$mode" = "standalone" ]; then
        Log DEBUG "start partition journal disk"
        total_size=`lsblk $disklist_journal | grep disk | awk '{print $4}'`
        if echo $total_size | grep -q "G"; then
            total_size=`echo $total_size | sed 's/G//'`
        elif echo $total_size | grep -q "T"; then
            total_size=`echo $total_size | sed 's/T//'`
            let total_size="$total_size*1024"
        else
            Log ERROR "do not recognize the disk $disklist_journal capacity"
        fi
        
        journal_percent=`echo "scale = 2; $journal_size / $total_size" | bc | tr -d '^.'`
        journal_percent=$((10#${journal_percent}))
        
        start_percent=0
        stop_percent=$journal_percent
        
        # TODO: disklist_journal is a single value now, if multi ssd, how to do?
        Run parted -s $disklist_journal mklabel $label_type
        
        # part osd_total_num * journal_size 
        for ((i=$osd_number_begin; i<=$osd_number_end; i++)); do
        
            # TODO: if multi SSD, calc journal on every SSD
            Run parted -s $disklist_journal mkpart osd-device-${i}-journal ${start_percent}% ${stop_percent}%
            
            let start_percent=$start_percent+$journal_percent
            let stop_percent=$stop_percent+$journal_percent
        done
    fi
    
    Log DEBUG "myPARTITIONDEV=${myPARTITIONDEV}"
    Log SUCC "partiton success"
    
    # 并行格式化磁盘
    Log DEBUG ""
    Log DEBUG "start to mkfs in parall"
    while read line; do 
        datadev=`echo $line | awk '{print $1}'`
        logdev=`echo $line | awk '{print $2}'`
        device_num=`echo $line | awk '{print $3}'`
        # ext4 DO NOT support logdev...
        Log DEBUG "mkfs.${fstype} -l logdev=$logdev,size=$mkfs_logdev_size -L osd-${device_num} ${mkfs_option} ${datadev}"
        mkfs.${fstype} -l logdev=$logdev,size=$mkfs_logdev_size -L osd-${device_num} ${mkfs_option} ${datadev} &
        echo $! >> ${myPARTITIONPID}
        
    done <${myPARTITIONDEV}
    
    # 等待格盘结束
    if [ -f ${myPARTITIONPID} ]; then
        for pid in `cat ${myPARTITIONPID}`; do
            wait $pid
        done
        rm -f ${myPARTITIONPID}
    fi
    Log SUCC "format success"
    
    
    # mount all data disk
    Log DEBUG ""
    Log DEBUG "start mounting disks"
    osd_frag_cron_file=/etc/cron.d/osd_frag
    [ -f $osd_frag_cron_file ] && >$osd_frag_cron_file
    while read line; do
        datadev=`echo $line | awk '{print $1}'`
        logdev=`echo $line | awk '{print $2}'`
        mountid=`echo $line | awk '{print $3}'`
        
        
        # auto mount
        auto_mount_file=/etc/fstab
        
        
        #add to the /etc/fstab
        ESCAPE_DIR=$(echo $datadev | sed 's/\//\\\//g')
        sed -i "/$ESCAPE_DIR/d" $auto_mount_file
        echo "$datadev ${ceph_osd_dir_prefix}${mountid}    ${fstype}   defaults,${CEPH_OSD_MOUNT_OPTION},logdev=$logdev    0 2" >> $auto_mount_file


        # set osd disk fragmentation  
        if [ -n "$CEPH_OSD_FRAG_PERIOD" ]; then
            # make crontab file
            if [ "$fstype" = "xfs" ]; then
                Log DEBUG "add $datadev fragmentation to cron file $osd_frag_cron_file"
                echo "* * */${CEPH_OSD_FRAG_PERIOD} * * xfs_db -c frag -r $datadev" >>$osd_frag_cron_file
            fi
        fi
        
        
    done <${myPARTITIONDEV}
    
    mount -a
    Check_Return $0 $LINENO $FUNCNAME
    
    chown -R $diskuser ${ceph_osd_dir_prefix}${mountid}
    Log SUCC "mount success"

    # TODO: wirte disk part info to $CEPH_OSD_PARTITION_RESULT
   
:<<EOF
[osd0]
    # part & size
    data=/dev/sdb1
    data_size=980
    data_partlabel=osd-device-0-data
    journal=/dev/sdb2
    journal_size=20
    journal_partlabel=osd-device-0-journal
    
    # filesystem
    fstype=xfs
    mkfs_option=""
    mount_option=""
    mount_point=/var/lib/ceph/osd0
    
    # user & group
    user=ceph
    group=ceph
EOF
}
