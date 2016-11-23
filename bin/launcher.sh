#!/usr/bin/env bash

#set -euo pipefail
#trap "echo 'error: Script failed: see failed command above'" ERR

# import functions
cd $(dirname $0)
. ../lib/functions
. ${LIB_DIR}/`basename ${0%.*}`.fun

# show welcome info
#Show_WelcomeS



# launcher it forground or underground(use for autotest)
# start_DaemonLauncher need to edit config file manual
# for more infomation, read the doc
if [ -t 1 ]; then
	:
    #Start_Launcher
else
	:
	#Start_DaemonLauncher
fi

testfun() {


	Return $0 $FUNCNAME 2

}
testfun