#!/bin/sh

# trap "rm -f /tmp/conn$main_pid.log" 0 1 2 5 15

ConnectTimeout="5"						#连接远程服务器outime
system_info="天涯Linux服务器管理系统SDR1.0"


server_value="192.168.0.184 192.168.0.1 192.168.0.184 192.168.0.184"
for slist in $server_value
 do
 	counter=`expr $counter + 1`
 	server_value_str=$server_value_str" "$slist
done;
Gap=`expr 100 / $counter`
num=0
PCT=$Gap
(
while test $PCT -le 100
do
	num=`expr $num + 1`
	vlist=`echo "$server_value_str"|awk -F " " '{print $'$num'}'`
	result=`ssh -i ./identity -oConnectTimeout=$ConnectTimeout root@$vlist " date " 2>&1`	
	result_do=$?
	if [ $result_do -eq 0 ]; then
	  		
		result_up_str="[√]$vlist：检测连接状态成功！服务器日期：$result"
	else
		result_up_str="[×]$vlist：检测连接状态失败，连接远程主机$vlist失败！"	
	fi
	echo "XXX"
	echo $PCT
	echo "\n正在连接$vlist主机...\n$result_up_str"
	echo "XXX"
	PCT=`expr $PCT + $Gap`
	#sleep 1
	
	#写运行结果到日志；
	echo "$result_up_str" >> /tmp/conn$main_pid.log
	echo "-------------------------------------------------------------------------" >> /tmp/conn$main_pid.log
	logs="[$(date +'%Y-%m-%d %H:%M:%S')]$result_up_str"
	#RecordLog	
done
) | dialog --title "$system_info" --gauge "\n\n\n\n\n　　　　　　　　　　　　　准备检测....." 18 70 0
dialog --title "$system_info" --clear \
        --textbox /tmp/conn$main_pid.log  40 80
