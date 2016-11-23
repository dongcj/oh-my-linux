#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description: md5 every file & total md5
#

# import functions
cd $(dirname $0)
. ../lib/functions

for i in `find ${BASE_DIR} -type f -exec grep -Il . {} \;`; do if grep -iq todo $i;\
 then echo "### $i ###"; grep -i todo $i; echo;echo;echo; fi; done 2>/dev/null