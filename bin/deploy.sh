#!/bin/bash
## CopyRight  krrishdo@gmail.com
## Author: Krrish

set -e

## Show the system configuration
ShowInfo(){
    clear
    echo
    echo -n "        |-------------------------------------------------------------------"
    echo -ne "\e[6n";read -sdR pos0;pos0=${pos0#*[};P0=${pos0/;/ };L0=${P0%% *};C0=${P0##* }
    echo
    echo -n "        |----------------- "
    echo -n "${BOLD}System information...${NORMAL}"
    echo " --------------------------"
    cat <<EOF
        |
        |    MACHINE TYPE: ${OS_ARCH}   MACHINE NAME: ${SYSTEM_PRODUCT_NAME}
        |
        |    1. Disk information
        |        Disk  list: ${DISK_LIST}
        |        Disk  size: ${DISK_SIZE} (GB)
        |        Disk count: ${DISK_COUNT}
        |
        |    2. Memory information
        |        Memory total: ${MEMORY_SIZE} (GB)
        |        Memory free : ${MEMORY_FREE} (GB)
        |
        |    3. CPU information
        |        Virtual  CPU(s): ${VIRTUAL_CPUS}
        |        Physical CPU(s): ${PHYSICAL_CPUS}
        |
        |    4. Network information
        |        Network ether(s): ${NET_ETHER_LIST}
        |        Ip address: ${IP_ADDRESS}
        |
EOF
    echo -n "        |------------------ Press \"q\" to quit, \"y\" to continue -------------"
    echo -ne "\e[6n";read -sdR pos1;pos1=${pos1#*[};P1=${pos1/;/ };L1=${P1%% *};C1=${P1##* }
    for ((i=$L1;i>=L0;i--));do
        tput cup `expr $i - 1` `expr $C1 - 1`;echo "|"
    done
    echo -e "\\033[$((L1));$((C1))H"

}


ConfirmInfo(){

    while true;do
    echo -n "           Is the preceding information correct? [q/y default:y]: "
    read -n1 ANS
    ANS=${ANS:0:1}
    case ${ANS} in
        Q|q)echo; exit 0;
        ;;
        Y|y|"")clear;break;
        ;;
          *)echo;echo;continue;
    esac
    done
}

cd $(dirname $0)
. ../lib/functions
. ../lib/preinstall.fun

Check_OS_Distrib

Install_Basic_Soft


ShowInfo
