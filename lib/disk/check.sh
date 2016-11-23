HOST=`hostname`
ERROR_LOG=/tmp/error_log

rm -rf $ERROR_LOG

PROFILE="db_ob_server"
DEFAULT_PATH="/usr/kerberos/bin:/home/admin/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/usr/X11R6/bin:/home/sekong.wsm/bin:/bin"
UNSS_PROC="telent|ftp|ntalk|rsh|rlogin|rexec"
ERROR_KEY="error|failure"

CS_MEM_SIZE=48
UPS_MEM_SIZE=192
MEM_SIZE=48

ELEVATOR=deadline

# system resoure limition
MAX_USR_PROC=131070
MAX_OPEN_FILE=131070

# sysctl configuration
SYSCTL_CONF="net.core.somaxconn = 2048|net.core.netdev_max_backlog = 10000|net.core.rmem_default = 16777216|net.core.wmem_default = 16777216|net.core.rmem_max = 16777216|net.core.wmem_max = 16777216|net.ipv4.ip_local_port_range = 1024 65535|net.ipv4.ip_forward = 0|net.ipv4.conf.default.rp_filter = 1|net.ipv4.conf.default.accept_source_route = 0|net.ipv4.tcp_syncookies = 0|net.ipv4.tcp_rmem = 4096 87380 16777216|net.ipv4.tcp_wmem = 4096 65536 16777216|net.ipv4.tcp_max_syn_backlog = 16384|net.ipv4.tcp_fin_timeout = 15|net.ipv4.tcp_max_syn_backlog = 16384|net.ipv4.tcp_tw_reuse = 1|net.ipv4.tcp_tw_recycle = 1|vm.swappiness = 0"

STATUS=true

is_rhel_5 ()
{
  if grep -q "release 5" /etc/redhat-release; then
    return 0
  else
    return 1
  fi
}

echo_error()
{
	echo -e "\033[41;36m Warnning: \033[0m""" $1
}

check_kernel()
{
	
	OS_VERSION=`cat /etc/issue | grep -i "Red hat" | cut -d"(" -f2 | cut -d")" -f1`
	case $OS_VERSION in
		# RHEL 5
		Tikanga)
		:
		uname -a | grep -i "2.6.18" > /dev/null
		if [ $? -ne 0 ];then
      echo "check_kernel FAILED"
			echo "Kernel version may error, check it" >> $ERROR_LOG
			return
		fi
		;;
		# RHEL 6
		Santiago)
		:
		uname -a | grep -i "2.6.32" > /dev/null
		if [ $? -ne 0 ];then
      echo "check_kernel FAILED"
			echo "Kernel version may error, check it" >> $ERROR_LOG
			return
		fi
		;;
	esac

	echo "Check kernel version ... OK"
}

check_bond_ms()
{
	if [ ! -f /proc/net/bonding/bond0 ];then
		echo "Bond mode may error, check it." >> $ERROR_LOG
		return
	fi

	SLAVE_IF1=`cat /proc/net/bonding/bond0 | grep -i "currently active slave" | cut -d":"  -f2`
	SLAVE_IF2=`cat /proc/net/bonding/bond0 | grep -i -E "^Slave Interface" | cut -d":" -f2 | grep -v $SLAVE_IF1`
  echo "SLAVE_IF1: ${SLAVE_IF1}"
  echo "SLAVE_IF2: ${SLAVE_IF2}"

	ifenslave -c bond0 $SLAVE_IF2
	ifenslave -c bond0 $SLAVE_IF2
	if [ $? -ne 0 ];then
		echo "Bond may have error, check it" >> $ERROR_LOG
		return
	fi
	ping -c 3 sa1.yh.aliyun.com > /dev/null
	if [ $? -ne 0 ];then
		echo "Bond cannot ping a server, check it" >> $ERROR_LOG
		return
	fi
	ifenslave -c bond0 $SLAVE_IF1

	echo "Check Bond0 ... OK"
}

check_bond_ups()
{
  grep -q 'Number of ports: 4' /proc/net/bonding/bond0
  if [ $? -eq 0 ];then
    echo "check_bond_ups OK"
  else
    echo "check_bond_ups FAILED"
  fi
}

check_bond()
{
  if [ $IS_UPS -eq 0 ];then
    check_bond_ups
  else
    check_bond_ms
  fi
}

check_mem()
{
	mem_size=`cat /proc/meminfo | head -n 1 | awk '{print $2}'`
	mem_size=`expr $mem_size / 1024 / 1000`
	if [ $mem_size -lt $MEM_SIZE ];then
		echo "memory size ${mem_size}G may error, FAILED"
		echo "memory size ${mem_size}G may error, check it." > $ERROR_LOG
	else
		echo "Check mem size OK"
	fi
}

# check id of a user
check_id()
{
	id $1 &> /dev/null
	if [ $? -ne 0 ];then
		echo "User $1 does not exist" >> $ERROR_LOG
		return
	fi

	USR_ID=`id -u $1`
	GRP_ID=`id -g $1`
	if [ $USR_ID -eq $2 ] && [ $GRP_ID -eq $3 ];then
		echo "Check uid and gid of $1 ... OK"
	else
		echo "uid and gid of $1 is not right" >> $ERROR_LOG
	fi
}

check_proc()
{
	ps aux | grep -i -E $UNSS_PROC | grep -v grep > /dev/null
	if [ $? -eq 0 ];then
		echo "check_proc FAILED"
	else
		echo "Check_proc OK"
	fi
}

check_default_proc()
{
	ps aux | grep -i -E $1 | grep -v grep > /dev/null
	if [ $? -ne 0 ];then
		echo "$1 is not running, check it." >> $ERROR_LOG
		echo "$1 is not running, FAILED"
	else
		echo "Check default process $1 ... OK"
	fi
}

check_default_procs()
{
  #-----------check default process----------
  check_default_proc crond
  #check_default_proc irqbalance
  check_default_proc ntpd
  check_default_proc snmpd
  check_default_proc sshd
  check_default_proc syslog-ng
}

check_sysctl()
{	
	check_one(){
		NAME=/proc/sys/`echo $@ | cut -d"=" -f1 | tr "." "/"`
		VALUE1=`cat $NAME | tr "\t" " "`
		VALUE2=`echo $@ | cut -d"=" -f2| sed 's/^ //g'`


		
		if [ "$VALUE1" != "$VALUE2" ];then
			echo "Sysctl $NAME configure may error, check it." >> /tmp/error_log
		else
			echo "Check $NAME ... OK"
		fi
	}

	export -f check_one
	echo $SYSCTL_CONF | awk -F"|" '{for(x=1;x<=NF;x++) system("check_one"" "$x)}'
}

check_reboot()
{
	REBOOT_TIME=`last |  grep -E -i "^reboot" | wc -l`
	if [ $REBOOT_TIME -lt 2 ];then
		echo "error: system has not reboot" >> $ERROR_LOG
		return
	else
		echo "Check reboot times ... OK."
	fi
}

check_ups_raid()
{
  if [ $IS_UPS -eq 1 ];then
    return
  fi

  #ups only has 1 raid adapter, vd 1 <--> ups commitlog dir
  vd_num=`/opt/MegaRAID/MegaCli/MegaCli64  -LDInfo -Lall -a0 -NoLog|grep 'Virtual Drive:'|wc -l`
  if [ ${vd_num} -le 2 ];then
    echo "check_ups_raid, only ${vd_num} vd found, FAILED "
    return
  fi

  commitlog_policy='Current Cache Policy: WriteBack, ReadAdaptive, Direct, Write Cache OK if Bad BBU'
  normal_policy='Current Cache Policy: WriteThrough, ReadAdaptive, Direct, Write Cache OK if Bad BBU'
  raid_level='RAID Level          : Primary-1, Secondary-0, RAID Level Qualifier-0'
  ret=0

  for((i=0;i<vd_num;i++))
  do
    if [ $i -eq 1 ];then
      /opt/MegaRAID/MegaCli/MegaCli64  -LDInfo -L${i} -a0 -NoLog|grep -q "${commitlog_policy}";ret=$?
    else
      /opt/MegaRAID/MegaCli/MegaCli64  -LDInfo -L${i} -a0 -NoLog|grep -q "${normal_policy}";ret=$?
    fi
    if [ $ret -ne 0 ];then
      break
    fi

    if [ $i -le 1 ];then
      /opt/MegaRAID/MegaCli/MegaCli64  -LDInfo -L${i} -a0 -NoLog|grep -q "${raid_level}";ret=$?
      if [ $ret -ne 0 ];then
        echo "check_ups_raid: raid level error, FAILED"
        return
      fi
    fi
  done

  if [ $ret -eq 0 ];then
    echo "check_ups_raid OK"
  else
    echo "check_ups_raid FAILED"
  fi
}

check_numa()
{
	
	NUMA_OK=true

	# check current numa stat
	num_node=`ls /sys/devices/system/node | grep "^node" | wc -w`
	if [ $num_node -gt 1 ];then
		echo "Current numa stat is on, ..." >> $ERROR_LOG
		NUMA_OK=false
	fi

	# check numa init parameter
	num_numa_cmd=`cat /etc/grub.conf | grep -i "title" | wc -l`
	num_numa_off=`cat /etc/grub.conf | grep -i "numa=off" | wc -l`

	if [ $num_numa_cmd -ne $num_numa_off ];then
		echo "Init numa parameter may have error, check it" >> $ERROR_LOG
		NUMA_OK=false
	fi

	if $NUMA_OK;then
		echo "check_numa is off OK"
  else
    echo "check_numa FAILED"
  fi
}

check_elevator()
{
	ELEVATOR_OK=true

	#check current elevator policy
	for DISK in `ls /sys/block | grep "sd\?"`
	do
		cat /sys/block/$DISK/queue/scheduler | grep "\[$ELEVATOR\]" > /dev/null
		if [ $? -ne 0 ];then
			echo "Evelator of $DISK may error, check it" >> $ERROR_LOG
			ELEVATOR_OK=false
		fi
	done
	# check elevator init parameter

	num1=`cat /etc/grub.conf | grep -i "title" | wc -l`
	num2=`cat /etc/grub.conf | grep -i "elevator=$ELEVATOR" | wc -l`

	if [ $num2 -ne $num1 ];then
		echo "Init elevator parameter may have error, check it" >> $ERROR_LOG
		ELEVATOR_OK=false
	fi


	if $ELEVATOR_OK;then
		echo "check_elevator policy, OK"
  else
		echo "check_elevator policy, FAILED"
  fi
}

check_user()
{

	USER_EXIST=true

	cat /etc/passwd | grep "^$1:" > /dev/null
	if [ $? -ne 0 ];then
		echo "User $1 account doesn't exist" >> $ERROR_LOG
		USER_EXIST=false
	else
		HOME_PATH=`cat /etc/passwd | grep "^$1:" | cut -d':' -f 6`
		if [ ! -d $HOME_PATH ];then
			echo "User $1 home directory doesn't exist" >> $ERROR_LOG
			USER_EXIST=false
		fi
	fi
	

	if $USER_EXIST;then
		echo "Check user $1 ... OK"
  else
		echo "Check user $1 ... FAILED"
  fi
}

check_dba_users()
{
  #------- check DBA user ------------------
  check_user suzhen
  check_user yushun.swh
  check_user shice.sc
  check_user qijie.tianqj
  check_user gongbo.yxh

  check_id admin 500 500
  check_id ob 510 510
}

check_rpm()
{
	RPM_INSTALLED=true

	if [ ! -f /tmp/rpm_log ];then
		rpm -qa > /tmp/rpm_log
	fi

	cat /tmp/rpm_log | grep -i "$1" > /dev/null
	if [ $? -ne 0 ];then
		echo "$1 is not installed FAILED" >> $ERROR_LOG
		RPM_INSTALLED=false
	fi

	if $RPM_INSTALLED;then
		echo "Check package $1 ... OK"
	fi
}

check_rpms()
{
  check_rpm kernel-devel
  check_rpm kernel-debuginfo
  check_rpm kernel-debuginfo-common
  check_rpm telnet
  check_rpm nmap
  check_rpm sysstat
  check_rpm ksh
  check_rpm syslinux
  check_rpm screen
}

check_limit_conf()
{
  if [ -e /etc/security/limits.d/oceanbase_limits.conf ];then
    echo "check_limit conf OK"
  else
    echo "check_limit conf FAILED"
  fi
}

check_limit()
{
	LIMIT_OK=true
	# max open file
	if [ `ulimit -n` -lt $MAX_OPEN_FILE ];then
		echo "Max open file configured error" >> $ERROR_LOG
		LIMIT_OK=false
	fi

	#max file locks
	if [ `ulimit -u` -lt $MAX_USR_PROC ];then
		echo "Max user processes configured error" >> $ERROR_LOG
		LIMIT_OK=false
	fi

	# cpu time
	if [ `ulimit -t` != "unlimited" ];then
		echo "Cpu time configure error" >> $ERROR_LOG
		LIMIT_OK=false
	fi

	if $LIMIT_OK;then
		echo "check_limit OK"
  else
    echo "check_limit FAILED"
  fi
}

check_ssh()
{
	:
	cat /etc/ssh/sshd_config | grep -i -E '^usedns' | grep -i "no" > /dev/null
	if [ $? -eq 0 ];then
		echo "check_sshd OK"
	else
		echo "check_sshd FAILED"
	fi
}

check_service()
{
  service_on=(irqbalance crond messagebus netfs network ntpd portmap rawdevices snmpd sshd syslog-ng DragoonAgent hubagent)
  for  i in ${service_on[@]}
  do
    if (! is_rhel_5) && [ "$i" == "irqbalance" ];then
      continue
    fi

    if ! chkconfig --list $i|grep -q '3:on';then
      echo "check_service [$i] FAILED"
      return
    fi
    echo "check_service [$i] OK"
  done
}

IS_UPS=1
check_init()
{
  lspci | grep -i raid | grep -Eq '(1078|9260|2108|2208)';IS_UPS=$?
  if [ $IS_UPS -eq 0 ];then
    MEM_SIZE=$UPS_MEM_SIZE
  else
    MEM_SIZE=$CS_MEM_SIZE
  fi
}

#main
check_init

check_mem
check_reboot
check_sysctl
check_proc
check_ssh

check_limit_conf
check_numa
check_elevator

check_bond
check_kernel

check_ups_raid
check_service

if [ -f $ERROR_LOG ];then
	echo "Checked `hostname` FAILED"
	cat $ERROR_LOG | while read ERROR_MSG
	do
		echo_error "$ERROR_MSG"
	done
	sleep 5
else
	echo "Checked `hostname` OK"
fi

rm -rf /tmp/rpm_log
rm -rf $ERROR_LOG
