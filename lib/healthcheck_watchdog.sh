#!/bin/bash
# check for: CPU / Mem / disk(badblocks, raid, fs error) AND io info

# add crontab:
# * * * * 6 /etc/scripts/healthcheck_watchdog.sh >> /var/log/healthcheck_watchdog.log 2>&1

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# use the scirpt name as bin name
# and export it to sub scripts
export BIN=`basename ${0%.*}`

LOGTIME='eval date "+%Y-%m-%d %H:%M:%S"'
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
echo "[ `$LOGTIME` | ${BIN} ]"

# import wechat alarm
mkdir -p /etc/scripts/.sender/
if ! [ -s /etc/scripts/.sender/wechat_alarm.sh ]; then
  echo "starting to download wechat_alarm.sh.."
  if ! curl -fsSL --connect-timeout 8 \
    https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0/raw/ >/etc/scripts/.sender/wechat_alarm.sh; then
        echo "download wechat_alarm.sh failed"
        echo "url: https://gist.github.com/dongcj/a5359c870fa4527a7e121e2f2c48b7f0/raw/"
        echo "you can download it to /etc/scripts/.sender/wechat_alarm.sh manual,"
        echo "and run it again."
        exit 1
  fi
fi
chmod a+x /etc/scripts/.sender/*.sh
  
# harbor base directory
export HARBOR_HOME="/opt/svicloud/tools/harbor"
cd $HARBOR_HOME

# the password store as: username  password
ID_FILE=/etc/scripts/.id/harbor
mkdir -p `dirname $ID_FILE` && touch $ID_FILE
[ -s $ID_FILE ] || { echo "please add \"username  password\" in $ID_FILE"; exit 1; }
USERNAME=`awk '{print $1}' $ID_FILE | xargs`
PASSWORD=`awk '{print $2}' $ID_FILE | xargs`

# service alive check, you shoud change the password
SERVER_ALIVE_CHECK="docker login -u $USERNAME -p $PASSWORD localhost"
COMPOSE_FILE="docker-compose.yml"
#COMPOSE_FILE="docker-compose.yml -f docker-compose.clair.yml -f docker-compose.notary.yml"


Check_Multi_Times() {
# check for 3 times
for i in `seq 3`; do
    echo "[ `$LOGTIME` | ${BIN} ] Trying to do login check after 15s."
    sleep 15
    if ${SERVER_ALIVE_CHECK} &>/dev/null; then
        echo "[ `$LOGTIME` | ${BIN} ] Service down and up $i result: success."
        /etc/scripts/.sender/*.sh success
        break
    else
        echo "[ `$LOGTIME` | ${BIN} ] Service down and up $i result: failed."
        /etc/scripts/.sender/*.sh error
    fi
 done  
}


# get all of the harbor service
ERROR_SERVICE=`docker-compose -f $COMPOSE_FILE  ps  | sed -n '1,2!p' | grep -v "Up" | \
    awk '{print $1}' | xargs`

if [ -n "${ERROR_SERVICE}" ]; then
    echo "[ `$LOGTIME` | ${BIN} ] Problem service(s): ${ERROR_SERVICE}, restarting harbor."
        
    docker-compose -f $COMPOSE_FILE down 
    sleep 3
    docker-compose -f $COMPOSE_FILE up -d 
    echo "[ `$LOGTIME` | ${BIN} ] Service restart complete."

    # check using docker login
    Check_Multi_Times
         
else
    echo "[ `$LOGTIME` | ${BIN} ] Service success."
    
    # login check
    echo "[ `$LOGTIME` | ${BIN} ] Trying to do login check."
    if ${SERVER_ALIVE_CHECK} &>/dev/null; then
        echo "[ `$LOGTIME` | ${BIN} ] Check login result: success."
        /etc/scripts/.sender/*.sh success
    else
        echo "[ `$LOGTIME` | ${BIN} ] Check login with: $SERVER_ALIVE_CHECK"
        echo "[ `$LOGTIME` | ${BIN} ] Check login result: failed."

        # doing docker-compose restart instead of down and up
        echo "[ `$LOGTIME` | ${BIN} ] Trying to do docker-compose down & up."
        docker-compose -f $COMPOSE_FILE down
        sleep 3
        docker-compose -f $COMPOSE_FILE up -d
        echo "[ `$LOGTIME` | ${BIN} ] Service restart complete."
        
        # check using docker login
        Check_Multi_Times
    fi
fi
