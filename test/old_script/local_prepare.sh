#!/usr/bin/env bash
# import the function
cd $(dirname $0)
. ../lib/functions
. ${LIB_DIR}/`basename ${0%.*}`".fun"


# touch the run file
MK_RunFile $0











sleep 30









# Delete the run file
RM_RunFile $0

# Exec the Next
Next_To_Run