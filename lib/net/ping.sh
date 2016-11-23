#!/bin/bash

#Parameter 1 specifies IP to ping
#Parameter 2 specifies port to use. If port is 0 then we will use normal ping instead of openinig socket on the target port / machine

NoSSH=1
count=400
status=1

while [ $NoSSH -eq 1 -a $count -ge 0 ]
do
    #echo "Checking sshd status"
    if [ $2 -eq 0 ]; then
        SSH=`ping $1 -c 1 -W 3`
    else
        SSH=`./server_connect.pl $1 $2`
    fi
    if [ "$?" == "0" ]
        then
            #echo "sshd deamon seems to be up and running"
                NoSSH=0
                #echo "NoSSH=$NoSSH"
                status=0
        exit $status
        fi

    count=`expr $count - 1`
        if [ $count -eq 0 ]
        then
            status=1
            exit $status
        fi
        sleep 5
done

exit $status
