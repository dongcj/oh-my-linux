#!/bin/bash

### Usage:

## import wechat alarm 
# mkdir -p /etc/scripts/.sender/ && curl -fsSL --connect-timeout 8 \
# https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0/raw/ >/etc/scripts/.sender/wechat_alarm.sh
# chmod a+x /etc/scripts/.sender/*.sh

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

# check the $BIN is already define
[ -z "$BIN" ] && echo "Please export BIN variable" && exit 1
DETAIL_LOG="/var/log/${BIN}.log"

HIS_DIR=/etc/scripts/.his/`date "+%Y"`/`date "+%m"`
HIS_FILE=${BIN}_`date "+%d"`
mkdir -p $HIS_DIR

IP_ADDR=$(ip route get 8.8.8.8 | grep src | \
  awk '{ i=1; while(i<NF) { if ( $i == "src" ) print $(i+1); i++ }}')
DATATIME=`date "+%Y%m%d-%H%M%S"`

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
# if there is no file or file does't contain
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
            MSG_TO_BE_SEND=false
        fi
            
    else
        # assum as first error when exception 
        ERR_NUM=1
        MSG_TO_BE_SEND=true
    fi
    
    echo -e "$DATATIME\t${LOGLEVEL}[${ERR_NUM}]" >>${HIS_DIR}/${HIS_FILE}  

## when succ, only one success msg to be send
elif [ "$LOGLEVEL" = "success" ]; then   
    
    # if the last row contain "error"
    if echo $LAST_ROW_CONTAIN_FLAG | grep -q "error"; then
        MSG_TO_BE_SEND=true
        
    else
        MSG_TO_BE_SEND=false
    fi
    
    echo -e "$DATATIME\t${LOGLEVEL}" >>${HIS_DIR}/${HIS_FILE}  
    
## usage error
else

     echo "[ `$NOW_TIME` | wechat_alarm ] wechat_alarm usage error!!!"
     exit 1
fi

}


TITLE_SHORT="${BIN}__Status_${LOGLEVEL}__${IP_ADDR}"

# only show last rows and add zero rows to first and last line
CONTENT_DETAIL=`tail -n ${MAX_LOG_DETAIL_ROWS} $DETAIL_LOG | \
  sed 's/$/\n/' | sed '1s/^/\n/' | sed '$G'`


  
# # loop to send wechat msg
Send_Msg() {

if $MSG_TO_BE_SEND; then

    for i in $NAME_AND_SCKEY; do
        SND_NAME=${i%%:*}
        SND_KEY=${i#*:}
        
        # let every msg has different content
        NOW_TIME=`date "+%Y/%m/%d %H:%M:%S"`
        MSG_ID=`date +%N`
        
        CONTENT_DETAIL_DESP="Dear_${SND_NAME}__msgid_${MSG_ID}__${CONTENT_DETAIL}"
        
        res=`curl -qs "http://sc.ftqq.com/${SND_KEY}.send?text=$TITLE_SHORT" \
          -d "&desp=$CONTENT_DETAIL_DESP"`
        
        # log 
        if echo $res | grep -q success; then
            echo "[ $NOW_TIME | ${BIN} ] send wechat msg: $MSG_ID to $SND_NAME success" | tee -a ${DETAIL_LOG}
        else
            echo "[ $NOW_TIME | ${BIN} ] send wechat msg: $MSG_ID to $SND_NAME failed" | tee -a ${DETAIL_LOG}
        fi
        
    done
fi
}

# Main
Log_Msg
Send_Msg

