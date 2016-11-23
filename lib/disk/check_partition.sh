#!/bin/bash
################################################################################
#Title: check_partition.sh
#Description: check partition of local disks
#Platform: Solaris10 u6
#Copyright: Copyright (c) 2010
#Author: 
#Version: 1.0
#Date: 2010.1.12
################################################################################

################################################################################
#
#  variable
#
################################################################################

#YEAR=`/usr/bin/date +%Y`
#MONTH=`/usr/bin/date +%m`
#DAY=`/usr/bin/date +%d`
#HOUR=`/usr/bin/date +%H`
#MIN=`/usr/bin/date +%M`
#SEC=`/usr/bin/date +%S`

INSTALL_DIR="/opt/installtmp"
LOGDIR="${INSTALL_DIR}/installstep"
if [ ! -d $LOGDIR ]
then
    /usr/bin/mkdir -p $LOGDIR
fi
LOG="${LOGDIR}/check_partition.log"
if [ -f $LOG ]
then
    rm -rf $LOG
    /usr/bin/touch $LOG
fi
TMPDIR="${INSTALL_DIR}/tmp"
if [ ! -d $TMPDIR ]
then
    /usr/bin/mkdir -p $TMPDIR
fi
CONFIG_FILE="/opt/installtmp/installstep/deploy.conf"

################################################################################
#
#   Function: writeLog
#   Desctiption: Writing log to $LOG
#
################################################################################
writeLog()
{
    if
        /usr/bin/echo "$1" | /usr/bin/grep "() | " > /dev/null
    then
        /usr/bin/echo "`/usr/bin/date '+%Y-%m-%d %T'` || `/usr/bin/echo $1 | /usr/bin/awk -F\"|\" '{print substr($2,2)}'`"
    else
        /usr/bin/echo "$1"
    fi
    /usr/bin/echo "`/usr/bin/date '+%Y-%m-%d %T'` || $1" >> $LOG
}


################################################################################
#
#   Function: infomation of local disk's partition 
#
################################################################################
partition_info()
{
    if [ $1 -ne 0 ]
    then
    	slice=$2
    	slice_sector_count=`cat $TMPDIR/partition_info | awk '$1=="'$slice'" {print $5}'`
    	if [ -z "$slice_sector_count" ]
    	then
            writeLog "check_partition_info() | Error: the partition s${slice} size of rootdisk is abnormal"
            return 1
        fi
        declare -i slice_size=`echo "${slice_sector_count}*512/1024/1024" | bc`
        if [ ${slice_size} -lt `expr $1 - 1000` ] || [ ${slice_size} -gt `expr $1 + 1000` ]
        then
      	    writeLog "check_partition_info() | Error: the partition(s${slice}) size of rootdisk is abnormal"
            return 1
        fi
    else
    	return 0
    fi
}  
  
################################################################################
#
#   Function: compare local disk's partition 
#
################################################################################
partition_compare()
{
    ROOTDISK=`cat $CONFIG_FILE | grep "ROOTDISK" | awk -F'=' '{print $2}'`
    if [ -z "$ROOTDISK" ]
    then 
    	writeLog "check_partition_compare() | Error: can't get the rootdisk from $CONFIG_FILE "
    	return 1
    fi
    prtvtoc /dev/dsk/${ROOTDISK}s2 | grep -v "^*" > $TMPDIR/partition_info 2>/dev/null
    if [ $? -ne 0 ]
    then
    	writeLog "check_partition_compare() | Error: can't get the partition information of rootdisk"
    	return 1
    fi
    ##### check the s0 s1 s2 s3 s4 s5 s6 s7 size 
    slice=-1
    for slicenum in $*
    do
    	slice=$(($slice + 1))
    	partition_info $slicenum $slice
    	if [ $? -ne 0 ]
    	then
      	    return 1
        fi
    done
}  
  

################################################################################
#
#   Function: check local disk's partition of sun4v
#
################################################################################
check_partition_sun4v()
{
    writeLog "check_partition_sun4v() | checking the partition of the system................."
    SERVER_TYPE=`cat $CONFIG_FILE | grep "INSTALLTYPE" | awk -F'=' '{print $2}'`
    if [ -z "$SERVER_TYPE" ]
    then
    	writeLog "check_partition_sun4v() | Error: can't get the server type please check $CONFIG_FILE"
    	return 1
    fi
    if [ $SERVER_TYPE -eq 1 ]
    then
    	######slice size   s0   s1  s2 s3 s4 s5   s6  s7, if size=0,then don't check the slice
    	partition_compare 30000 16000 0 0 0 0 1024 0
    	if [ $? -ne 0 ]
    	then
            return 1
        fi
    elif [ $SERVER_TYPE -eq 2 -o $SERVER_TYPE -eq 3 -o $SERVER_TYPE -eq 9 -o $SERVER_TYPE -eq 10 -o $SERVER_TYPE -eq 11 ]
    then 
    	partition_compare 110000 20000 0 0 0 0 1024 0
    	if [ $? -ne 0 ]
    	then
            return 1
     	fi          
    elif [ $SERVER_TYPE -eq 5 -o $SERVER_TYPE -eq 6 -o $SERVER_TYPE -eq 7 -o $SERVER_TYPE -eq 8 ]
    then 
    	partition_compare 100000 20000 0 0 0 10000 1024 0
    	if [ $? -ne 0 ]
    	then
      	    return 1
        fi
    else
    	writeLog "check_partition_sun4v() | Error: the server type $SERVER_TYPE is not support on sun4v"
    	return 1
    fi 
}


################################################################################
#
#   Function: check local disk's partition of sun4u
#
################################################################################
check_partition_sun4u()
{
    writeLog "check_partition_sun4u() | checking the partition of the system................."
    SERVER_TYPE=`cat $CONFIG_FILE | grep "INSTALLTYPE" | awk -F'=' '{print $2}'`
    if [ -z "$SERVER_TYPE" ]
    then
    	writeLog "check_partition_sun4u() | Error: can't get the server type please check $CONFIG_FILE"
    	return 1
    fi
    MACHINE_NAME=`cat $CONFIG_FILE | grep "MACHINENAME" | awk -F'=' '{print $2}'`
    if [ -z "$MACHINE_NAME" ]
    then
    	writeLog "check_partition_sun4u() | Error: can't get the machine name please check $CONFIG_FILE"
    	return 1
    fi
    ##对各种机型分方案来检查分区大小
    if [ "$MACHINE_NAME" = "V240" -o "$MACHINE_NAME" = "V245" ]
    then
    	if [ $SERVER_TYPE -eq 1 ]
    	then
            partition_compare 19000 4096 0 23500 8500 13000 0 0
            if [ $? -ne 0 ]
            then
            	return 1
            fi
        else
      	    echo
        fi
    elif [ "$MACHINE_NAME" = "V440" -o "$MACHINE_NAME" = "V445" ]
    then
    	if [ $SERVER_TYPE -eq 1 -o $SERVER_TYPE -eq 7 -o $SERVER_TYPE -eq 8 ]
    	then
            partition_compare 30000 8192 0 0 0 0 0 0
      	    if [ $? -ne 0 ]
            then
        	    return 1
      	    fi
        else
            echo
        fi
    elif [ "$MACHINE_NAME" = "V890" ]
    then
    	if [ $SERVER_TYPE -eq 1 ]
    	then
      	    partition_compare 30000 16000 0 0 0 0 1024 0
            if [ $? -ne 0 ]
      	    then
        	    return 1
      	    fi
      	elif [ $SERVER_TYPE -eq 2 -o $SERVER_TYPE -eq 3 -o $SERVER_TYPE -eq 5 -o $SERVER_TYPE -eq 6 -o $SERVER_TYPE -eq 7 -o $SERVER_TYPE -eq 8 -o $SERVER_TYPE -eq 9 -o $SERVER_TYPE -eq 10 -o $SERVER_TYPE -eq 11 ]
      	then
      	    partition_compare 110000 20000 0 0 0 0 1024 0
            if [ $? -ne 0 ]
      	    then
        	    return 1
      	    fi
        else
      	    writeLog "check_partition_sun4u() | Error: the Netra 240 administration console is support on $MACHINE_NAME"
            return 1
        fi
    elif [ "$MACHINE_NAME" = "M4000" -o "$MACHINE_NAME" = "M5000" ]
    then
    	if [ $SERVER_TYPE -ne 4 ]
    	then
      	    partition_compare 110000 20000 0 0 0 0 1024 0
            if [ $? -ne 0 ]
      	    then
        	    return 1
      	    fi
    	else
      	    writeLog "check_partition_sun4u() | Error: the Netra 240 administration console is not support on $MACHINE_NAME"
      	    return 1
        fi
    elif [ "$MACHINE_NAME" = "E4900" -o "$MACHINE_NAME" = "N240" ]
    then
        echo     
    else
    	writeLog "check_partition_sun4u() | Error: the machine name $MACHINE_NAME is not support"
    	return 1
    fi
   
}

# =============== main ================
main()
{
    writeLog "main() | "
    writeLog "main() | ====================================================="
    writeLog "main() | =========== Executing check_partition.sh ============"
    writeLog "main() | ====================================================="
    writeLog "main() | "
    if [ ! -f $CONFIG_FILE ]
    then
      	writeLog "main() | Error: can't find the config file $CONFIG_FILE"
      	exit 1
    fi
    if [ "`uname -m`" = "sun4v" ]
    then
      	check_partition_sun4v
      	if [ $? -ne 0 ]
      	then
            exit 1
      	else
            writeLog "main() | Ok: check the partition size of  rootdisk completely"
        fi
    elif [ "`uname -m`" = "sun4u" ]
    then
      	check_partition_sun4u
      	if [ $? -ne 0 ]
      	then
            exit 1
      	else
            writeLog "main() | Ok: check the partition size of  rootdisk completely"
      	fi
    else
      	writeLog "main() | Error: the sun machine type `uname -m` is not support"
      	exit 1
    fi
      
}
### 主函数入口 Entrance
main
