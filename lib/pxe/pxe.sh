#!/bin/sh
#****************************************************************#
# ScriptName: pxe.sh
# Author: $SHTERM_REAL_USER@alibaba-inc.com
# Create Date: 2015-11-09 19:54
# Modify Author: $SHTERM_REAL_USER@alibaba-inc.com
# Modify Date: 2016-02-19 19:06
# Function: 
#***************************************************************#
#!/bin/bash

snlist=$1
./get_oobip.sh $snlist > sniplist
#pwd="1qaz2wsx"
pwd="9ijn0okm"

cat sniplist | while read line
do
  sn=`echo $line | awk '{print $1}'`
  ip=`echo $line | awk '{print $2}'`
  [[ "$ip" == "" ]] && (echo "no oob ip"; continue)
  ipmitool -I lanplus -H $ip -U taobao -P $pwd chassis bootdev pxe
  ipmitool -I lanplus -H $ip -U taobao -P $pwd power reset
  [[ $? -eq 0 ]] || echo "$sn $ip -> PXE fail"
done 
