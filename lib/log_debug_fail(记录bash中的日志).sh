#!/bin/bash
SCRIPT_NAME=$(basename $0)
LOG_FILE=/var/log/${SCRIPT_NAME%.*}.log

FBS_ESC=`echo -en "\033"`
COLOR_RED="${FBS_ESC}[1;31m"       # Error
COLOR_CLOSE="${FBS_ESC}[0m"

echo $LOG_FILE


log()  { printf "%b\n" "$*"; echo -e "$*" >>$LOG_FILE; }
debug(){ [[ ${DEBUG:-0} -eq 0 ]] && echo "$*" >>$LOG_FILE || printf "%b\n" "Running($#): $*"; }
fail() { printf "${COLOR_RED}\nERROR: $* \n${COLOR_CLOSE}\n"; echo -e "$*" >>$LOG_FILE; exit 1 ; }    
