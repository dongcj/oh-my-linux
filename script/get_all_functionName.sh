#!/bin/bash

# import functions
cd $(dirname $0)
. ../lib/functions


FUNC_FILE="${BASE_DIR}/lib/functions ${BASE_DIR}/lib/*.fun"

for i in `echo $FUNC_FILE`; do 

    echo "################### FUNCFILE = $i"
    for j in $i; do
        func_name=`grep "^[a-zA-Z].*() *{" $j`
        echo $func_name | xargs -n2
        echo
    done

        
        
done