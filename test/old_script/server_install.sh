#!/usr/bin/env bash
# import the function
cd $(dirname $0)
. ../lib/functions
. ${LIB_DIR}/`basename ${0%.*}`".fun"

# touch the run file
MK_RunFile $0





















# Delete the run file
RM_RunFile $0

# Exec the Next