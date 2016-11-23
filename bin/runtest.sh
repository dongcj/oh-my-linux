#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
#
# description: 
# usage: 
# create: `date`
# modified: 


## cp
rm -rf /tmp/Ceph_AI/
cp -r /Users/dongcj/Google\ Drive/01-Development/Ceph_AI /tmp/
cd /tmp/Ceph_AI/

bash ./bin/launcher.sh

echo "cat log.."
cat /tmp/Ceph_AI/log/*.log

cd -



