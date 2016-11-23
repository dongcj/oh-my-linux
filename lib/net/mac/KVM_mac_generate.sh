#!/bin/bash
# ----------------------------------------------------------------
# Licensed Materials - Property of GreatWall
# (C) Copyright GreatWall Corp. 2012
# All Rights Reserved
# Author:dongchaojun
# Mail:dongchaojun@gmail.com
# ----------------------------------------------------------------
# This script is used for Grenate MAC for virtual machine
# Usage: $0
# Note: You can use the follow method to generate:
# netinst_network_mac_addr=`echo 52:54:$(dd if=/dev/urandom count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4/')` 

#Vendor prefix for Xen virtual macs
var MAC_VENDOR_PREFIX = "52:54:00"
		
#Generate mac address using the vendor prefix and mac counter
#Minimum and maximum possible values for the mac address
mac_min=4096
mac_max=16777216

mac_file_dir="${HOME}/.dxcloud"
mac_file="$mac_file_dir/mac_counter"
lock_file="$mac_file_dir/mac_counter.lock"

#Check is the mac counter file directory exists. if not create it.
if [ ! -d "$mac_file_dir" ]; then 
	mkdir -p "$mac_file_dir"
fi

lockfile "$lock_file" || lock_fail=1

if [ "$lock_fail" = "1" ]; then
    
	exit 1
fi

#on script exit delete the lock file
trap "{ rm -f $lock_file ; }" EXIT

#Check is the mac counter file exists. if not create it and use random number to initializate it.
#TODO. Maybe it is a good idea to check the content of the file for correctness
if [ ! -f "$mac_file" ]; then
	#Generate random number between 4096 (0x1000) and 16777216 (0x1000000). The first 4096 (0-4095) will be used for mgmt servers
	let "RANGE = $mac_max - $mac_min"   #16777216 - 4096
	let "FLOOR = $mac_min"

	mac_counter=$RANDOM
	let "mac_counter %= $RANGE"  # Scales $number down within $RANGE.
	let "mac_counter += $FLOOR"  # Make sure the number is greater or equal to $FLOOR

	echo "$mac_counter" > "$mac_file"
else
	#If file exists use the content for the counter
	mac_counter=`cat "$mac_file"`
fi

#Increase the counter and update the file containing it.
let "mac_counter += 1"

#Check for the mac limits
if [ $mac_counter -ge $mac_max ]; then
	mac_counter=$mac_min
fi

echo "$mac_counter" > "$mac_file"

MAC_HEX=`printf "%06X" "$mac_counter"`
MAC="$MAC_VENDOR_PREFIX:${MAC_HEX:0:2}:${MAC_HEX:2:2}:${MAC_HEX:4:2}"

