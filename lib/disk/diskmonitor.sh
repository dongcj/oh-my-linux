#!/usr/bin/env bash
# write by junrui @2012-12-5
# version 0.3
# for alipay DB
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
SN=$(dmidecode -s system-serial-number | awk '/^[^#]/ { print $1 }')
VENDOR=$(dmidecode -s system-manufacturer | awk '/^[^#]/ { print $1 }')
PRODUCT=$(dmidecode -s system-product-name | awk '/^[^#]/')
DISKINFO=$(mktemp)
HPACUCLI=/usr/sbin/hpacucli
MEGACLI=/opt/MegaRAID/MegaCli/MegaCli64

install() {
    local package=$1
    wget -qO /etc/yum.repos.d/alipay.repo http://sysinstall.zue.alipay.com/repo/files/alipay.repo
    yum -q -y install $package &>/dev/null
}

hp_checkdisk() {
    rpm --quiet -q hpacucli || install hpacucli
    local slot=$($HPACUCLI ctrl all show status | awk '/Slot/ { print $6 }')
    [[ -z "$slot" ]] && exit 1
    for num in $slot
    do
        $HPACUCLI ctrl all show status
        $HPACUCLI ctrl slot=$num pd all show status
    done >> $DISKINFO 2>&1
    awk '/Fail|Disabled|Recharging/ { $1 = $1; printf "%s\n", $0 }' $DISKINFO
}

dell_checkdisk() {
    rpm --quiet -q MegaCli || install MegaCli
    $MEGACLI -AdpAllInfo -aAll -NoLog > $DISKINFO 2>&1
    awk '{ regexp="^[[:blank:]]+(Degraded|Offline|Critical Disks|Failed Disks)" } ($0 ~ regexp && $NF > 0) { $1 = $1; printf "%s ", $0 } END { print "" }' $DISKINFO
    $MEGACLI -PDlist -aALL -NoLog > $DISKINFO 2>&1
    awk '
    BEGIN {FS="\n"; RS = ""}
    {
        regexp="\\w+ (Error Count: [1-9]+|Failure Count: [1-9]+)|Firmware state: Failed"
        str = $0
        while (match(str, regexp) > 0) {
            printf "%s %s\n", $2, substr(str, RSTART, RLENGTH)
            str = substr(str, RSTART + RLENGTH)
        }
    }' $DISKINFO
}

[[ $VENDOR == "HP" ]] && MSG=$(hp_checkdisk)
[[ $VENDOR == "Dell" ]] && MSG=$(dell_checkdisk | sed '/^$/d')

[[ "$MSG" =~ [[:alpha:]] ]] && _MSG=$(tr '\n' ' ' <<< "$MSG") && /home/oracle/admin/bin/sendnsca.sh 2 LOGWATCH2 "$_MSG" && curl -X POST -d "hostname=${HOSTNAME}&vendor=${VENDOR}&hwtype=${PRODUCT}&sn=${SN}&errlog=${MSG}" http://sam.global.alipay.com/api/hwlog/ && rm $DISKINFO
