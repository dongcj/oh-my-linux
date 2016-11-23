#!/bin/sh

. /etc/profile
CMD=/opt/MegaRAID/MegaCli/MegaCli64
VENDOR=`dmidecode |grep "Vendor"|awk '{print $2}'`


if [ $VENDOR == "Dell" ]; then
    if [ ! -e $CMD ]; then
        Log ERROR "megacli is not installed"
    
    fi

    LEARNMODE=`$CMD -AdpBbuCmd -GetBbuProperties -aALL|grep Auto-Learn|awk '{print $3}'`
    if [ $LEARNMODE != "Enabled" ]; then
        Log WARN "autolearn mode is disable"
    fi
    
    TIME=`date +%H`
    if [ $TIME -lt "2" ]; then
        NLTIME=`$CMD -AdpBbuCmd -GetBbuProperties -aALL|grep "Next Learn time"|awk '{print $4}'`
        NLTIME=`date -d "2000-01-01 UTC $NLTIME seconds" +%s`
        NOWTIME=`date +%s`
        let DLTIME=NOWTIME+864000
        
        if [ $DLTIME -ge $NLTIME ]; then 
            $CMD -AdpBbuCmd -BbuLearn -aALL
        fi
    else
        STATE=`$CMD -LDInfo -Lall -aALL|grep "Current Cache Policy"|awk '{print $4}'`
        
        if [ $STATE != "WriteBack," ]; then 
            Log WARN "It's critical. raid controller is using WRITE THROUGH"
        fi
    fi
fi
