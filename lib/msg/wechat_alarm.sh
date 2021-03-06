#!/bin/bash

### Usage:

:<<EOF
#import wechat alarm
mkdir -p /etc/scripts/.sender/
if ! [ -f /etc/scripts/.sender/wechat_alarm.sh ]; then
  echo "starting to download wechat_alarm.sh.."
  if ! curl -fsSL --connect-timeout 20 \
    https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0/raw/ >/etc/scripts/.sender/wechat_alarm.sh; then
        echo "download wechat_alarm.sh failed"
        echo "url: https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0/raw/"
        echo "you can download it to /etc/scripts/.sender/wechat_alarm.sh manual"
        echo "and run it again"
        exit 1
  fi
fi
chmod a+x /etc/scripts/.sender/*.sh
EOF

## send alarm
# /etc/scripts/.sender/*.sh <success|error>

## Note: please update it to gist:
# https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0


# get log level
LOGLEVEL=$1

# serverchan key, name:key, use space to separate
NAME_AND_SCKEY="krrish:SCU3387T597a45f4b3742b3cbf8e82e1adf5f4d1580c168d1858b"

# max msg send times
MAX_SEND_TIMES=3

# max log detail rows
MAX_LOG_DETAIL_ROWS=20

# check the $BIN is already defined by parent
[ -z "$BIN" ] && echo "Please export BIN variable" && exit 1
DETAIL_LOG="/var/log/${BIN}.log"
[ -f "$DETAIL_LOG" ] || touch $DETAIL_LOG

HIS_DIR=/etc/scripts/.his/`date "+%Y"`/`date "+%m"`
HIS_FILE=${BIN}_`date "+%d"`
mkdir -p $HIS_DIR

IP_ADDR_LOCAL=$(ip route get 8.8.8.8 | grep src | \
  awk '{ i=1; while(i<=NF) { if ( $i ~ "src" ) print $(i+1); i++ }}')
IP_ADDR_OUTTER=`curl -s --noproxy --connect-timeout 5 -4 ip.sb`

if [ "$IP_ADDR_LOCAL" = "$IP_ADDR_OUTTER" ]; then
    IP_ADDR="`uname -n`(${IP_ADDR_OUTTER})"
else
    IP_ADDR="`uname -n`(${IP_ADDR_LOCAL}|${IP_ADDR_OUTTER})"
fi

DATATIME=`date "+%Y%m%d-%H%M%S"`

# pre-generate the MSG id
MSG_ID=`date +%N`

[ -z "$MSG_ID" ] && MSG_ID=`head -20 /dev/urandom | md5sum | head -c 9`

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

   elif grep -Eqi "OpenWrt" /etc/openwrt_release  &>/dev/null || \
   grep -Eq "OpenWrt" $RELEASE_FILE &>/dev/null; then
       OS=OpenWrt
       PKG_INST_CMD="opkg install"
       RELEASE_FILE=/etc/openwrt_release       
   else
       echo "Not support OS, Please confirm OS Distribution or try again!"
       exit 1
   fi
}

# install dep
which jq &>/dev/null || { Check_OS_Distrib; $PKG_INST_CMD jq; }

# get Alarm from history file,
# the app should write alarm to alarm file first.
# the alarm directory is separate by date, like: 
#   /etc/scripts/.his/$YEAR/$MONTH/$BIN_$DAY.log
# the log history like below, add by function Log_History() 
#   $TIME  $LOGLEVEL(error,success)

# log to /etc/scripts/.his/
# and send (or not) msg
Log_Msg() {

## get the last log
# if there is no file or file does't contain success|error
if ! grep -Eq "error|success" ${HIS_DIR}/${HIS_FILE} 2>/dev/null; then

    # get all of the history in this month
    # this means if error cross over month, it will lost the error count
    # i think is not the best, but not bad...
    LAST_ROW_CONTAIN_FLAG=$(cat ${HIS_DIR}/${BIN}_* 2>/dev/null | grep -E "error|success" | tail -n1)
    
    # initial
    if [ -z "$LAST_ROW_CONTAIN_FLAG" ]; then
        echo -e "$DATATIME\tinitial" >>${HIS_DIR}/${HIS_FILE} 
    fi
    
else

    LAST_ROW_CONTAIN_FLAG=$(grep -E "error|success" ${HIS_DIR}/${HIS_FILE} | tail -n1)
fi

## when error 
if [ "$LOGLEVEL" = "error" ]; then   
    
    # if the last row contain "success"
    if echo $LAST_ROW_CONTAIN_FLAG | grep -q "success"; then
        ERR_NUM=1
        MSG_TO_BE_SEND=true
     
    # if the last row contain error
    elif echo $LAST_ROW_CONTAIN_FLAG | grep -q "error"; then
            
        # get the last num
        ERR_NUM=$(echo $LAST_ROW_CONTAIN_FLAG | awk -F'[' '{print $NF}' | awk -F']' '{print $1}')

        # if the ERR_NUM is not numric, reset
        if [ -n "`echo "$ERR_NUM" | tr -d \[0-9\]`" ]; then
            ERR_NUM=0
        fi
        
        # accumulation
        ERR_NUM=$((ERR_NUM+1))

        # just send 3 times error msg
        if [ $ERR_NUM -le $MAX_SEND_TIMES ]; then
            MSG_TO_BE_SEND=true
        else
            # continue to send, but 30 checks only send one alarm
            if [ $((ERR_NUM%30)) = 0 ]; then
                MSG_TO_BE_SEND=true
            else
                MSG_TO_BE_SEND=false
            fi    
            
        fi
            
    else
        # assum as first error when exception 
        ERR_NUM=1
        MSG_TO_BE_SEND=true
    fi
    
    echo -e "$DATATIME\t${LOGLEVEL}[${ERR_NUM}]" >>${HIS_DIR}/${HIS_FILE}  

## when success, only one success msg to be send
elif [ "$LOGLEVEL" = "success" ]; then   
    
    # if last row contain "error"
    if echo $LAST_ROW_CONTAIN_FLAG | grep -q "error"; then
        MSG_TO_BE_SEND=true
        
    else
        # if last row contain failed, need to send
        if echo $LAST_ROW_CONTAIN_FLAG | grep -q "failed"; then
            MSG_TO_BE_SEND=true
        else
            MSG_TO_BE_SEND=false
        fi

    fi
    ERR_NUM=0
    echo -e "$DATATIME\t${LOGLEVEL}" >>${HIS_DIR}/${HIS_FILE}  
    
## usage error
else

     echo "wechat_alarm usage error!!!"
     exit 1
fi

}

  
# # loop to send wechat msg
Send_Msg() {

TITLE_SHORT="${BIN}__Status_${LOGLEVEL}__${ERR_NUM}__${IP_ADDR}"

# only show last rows and add zero rows to first and last line
CONTENT_DETAIL=`cat $DETAIL_LOG | tail -n ${MAX_LOG_DETAIL_ROWS} | \
  sed 's/$/\n/' | sed '1s/^/\n/' | sed '$G'`

if $MSG_TO_BE_SEND; then

    for i in $NAME_AND_SCKEY; do
        SND_NAME=${i%%:*}
        SND_KEY=${i#*:}
        
        # let every msg has different content
        NOW_TIME=`date "+%Y-%m-%d %H:%M:%S"`
        
        CONTENT_DETAIL_DESP="Dear_${SND_NAME}__msgid_${MSG_ID}__${CONTENT_DETAIL}"
        
        res=`curl -qs "http://sc.ftqq.com/${SND_KEY}.send?text=$TITLE_SHORT" \
          -d "&desp=$CONTENT_DETAIL_DESP"`
        
        # log 
        if echo $res | grep -q success; then
        
            # record the send log
            sed -i "s/$DATATIME.*/\0 $MSG_ID=ok/" ${HIS_DIR}/${HIS_FILE}
            echo "[ $NOW_TIME | ${BIN} ] send wechat msg: $MSG_ID to $SND_NAME ok"
        else
            sed -i "s/$DATATIME.*/\0 $MSG_ID=failed/" ${HIS_DIR}/${HIS_FILE}
            echo "[ $NOW_TIME | ${BIN} ] send wechat msg: $MSG_ID to $SND_NAME failed"
        fi
        
    done
fi
}

# Main
Log_Msg
Send_Msg

