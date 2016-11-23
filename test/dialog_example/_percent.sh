#!/bin/bash  
# vim gauge.sh
declare -i PERCENT=0
(
        for I in /etc/*;do
                if [ $PERCENT -le 100 ];then
                        cp -r $I /tmp/test 2> /dev/null
                        echo "XXX" 
                        echo "Copy the file $I ..." 
                        echo "XXX" 
                        echo $PERCENT  
                fi
        let PERCENT+=1
        sleep 0.1
        done
) | dialog --title "coping" --gauge "starting to copy files..." 6 50 0
