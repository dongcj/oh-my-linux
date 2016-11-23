#!/bin/bash

# import functions
cd $(dirname $0)
. ../lib/functions


for i in `find ${BASE_DIR} -type f -exec grep -Il . {} \;`; do if grep -iq todo $i;\
 then echo "### $i ###"; grep -i todo $i; echo;echo;echo; fi; done 2>/dev/null