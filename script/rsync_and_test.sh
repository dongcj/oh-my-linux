#!/bin/bash

# import functions
cd $(dirname $0)
. ../lib/functions


rsync -avz 192.168.120.245:/root/Ceph_AI/ /root/Ceph_AI/ >/dev/null

cd /root/Ceph_AI/

./bin/install
