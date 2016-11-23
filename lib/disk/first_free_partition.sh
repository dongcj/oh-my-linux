#!/bin/bash

#################################################
# find the first unmounted partition in a device
# @return the free device
#################################################

dev_name=$1
if [ "x$dev_name" = "x" ]; then
    echo "Usage: first_free_partition.sh <device_name>"
    exit 1
fi

# find the free partition
pars=(`fdisk -l $dev_name | grep 'Linux$' | awk '{print $1}'`)
parmnt=(`mount -l | grep $dev_name | awk '{print $1}'`)
i=0
for par in ${pars[@]};do
    for mnt in ${parmnt[@]};do
        if [ $par = $mnt ]; then
            unset pars[i]
            break
        fi
    done
    i=`expr $i + 1`
done

#get the first free partition
pars=(`echo ${pars[@]}`)
num=${#pars[@]}
if [ $num -ne 0 ]; then
    echo ${pars[0]}
    exit 0
fi
exit 1

