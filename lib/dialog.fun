#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description: 
#

#############################################################################
# 作用: 提示用户输入IP地址和密码
# 用法: Dialog_Welcome
# 注意：
#############################################################################

Dialog_Welcome() {
    # speical setting
    TIMEOUT=10
    
    option="--width=${WIDTH} --heigh=${HEIGHT} --title=${TITLE} --window_icon=${WINDOW_ICON} \
    --image=${IMAGE} --timeout=${TIMEOUT} --timeout-indicator=${TIMEOUT_INDICATOR} "
    [ "$CENTER" == "yes" ] && option+=" --center" 
    [ "$FIXED" == "yes" ] && option+=" --fixed" 
    [ "$STICKY" == "yes" ] && option+=" --sticky" 
    [ "$MOUSE" == "yes" ] && option+=" --mouse" 
    [ "$ON_TOP" == "yes" ] && option+=" --on-top" 
    
    
    # yad
    echo option is $option
    yad $option 



}



#############################################################################
# 作用: 提示用户输入IP地址和密码
# 用法: Dialog_Welcome
# 注意：
#############################################################################
Show_Welcome() {

    # if silence mode, DO NOT show welcome
    if [ "$SILENCE_MODE" != "yes" ]; then

        if which figlet >&/dev/null; then
            echo "    Ceph AI" | figlet
        
        fi

        Draw_Line2 100
        
        if which lolcat >&/dev/null; then
            cat ${LIB_DIR}/version | lolcat -F "0.3"
        else
            cat ${LIB_DIR}/version
        fi

        if which cstream >&/dev/null; then
            
            
            echo -n "    Welcome, my friend, let's start with enter [ ]" | lolcat  | cstream -b1 -t20 
            
            # get the position
            echo -en "\e[6n";read -sdR pos;pos=${pos#*[};P=${pos/;/ };eval L_END=${P%% *}; eval C_END=${P##* }
            
        fi
        
        echo
        Draw_Line2 100

        # return to position
        tput cup `expr $L_END - 1`  `expr $C_END - 3`
        
        read ans
        
        # it is right
        tput cup `expr $L_END - 1`  `expr $C_END - 3`
        echo -n "${COLOR_GREEN}√${COLOR_CLOSE}"
        sleep 1
        clear
        
    fi
}

#############################################################################
# 作用：给一个列表，变成用户选择项; 选择项存进$3中, 值存进$4中
# 用法: Ask_Select
# 注意: 选择方式: 单选: 1;  多选: 1,2,3,4 或 1-4
#############################################################################
Ask_Select(){

    ALL_AVAIL_SELECT=($1)
    QUESTION=${2:-"Please select the item in which you want to install:"}
    VARIABLE="$3"
    VALUE="$4"
    
    # clear the old value
    unset $VALUE
    
    
    while true; do
        unset this_value
        Draw_Line 80%
        echo -e "  ${QUESTION}: "
        echo
        
        # show the PRODUCT
        for ((i=0; i<${#ALL_AVAIL_SELECT[*]}; i++)); do
            echo "    `expr $i + 1`: ${ALL_AVAIL_SELECT[i]/_/ }"
        done
        
        echo
        
        # no select before
        if [ -z "${!VARIABLE}" ]; then
            echo -n "  Please enter you choice [ 1-`expr ${#ALL_AVAIL_SELECT[*]}` ]: "
            
        # alreay selected at early time
        else
            echo -n "  Please enter you choice [ 1-`expr ${#ALL_AVAIL_SELECT[*]}`, default ${!VARIABLE} ]: "
        
        fi 
        
        read ANS;
        
        # use the history value
        ANS=${ANS:-`echo ${!VARIABLE}`}
        
        # input nothing 
        if [ -z "$ANS" ]; then
            echo "  ${COLOR_RED}Please follow the rules!!${COLOR_CLOSE}"
            echo
            continue
        fi
        
        ## has input
        # if a single key
        if [ `echo $ANS | tr '-' ' ' | tr ',' ' ' | awk '{print NF}'` -eq 1 ]; then

            # check is number                
            if [ -n "`echo $ANS | tr -d "0-9"`" ]; then
                echo "  ${COLOR_RED}Incorrect choice, please input NUMBER >0!!${COLOR_CLOSE}"
                echo 
                continue
            fi
            
            # must >0
            if [ $ANS -eq 0 ]; then
                echo "  ${COLOR_RED}Incorrect choice, 0 is not allowd!!${COLOR_CLOSE}"
                echo 
                continue
            fi
        
        
            # check value in range
            if [ "$ANS" -le "${#ALL_AVAIL_SELECT[*]}" ] 2>/dev/null; then
                eval $VARIABLE=`echo $ANS`
                eval $VALUE=\"${ALL_AVAIL_SELECT[ANS-1]}\"
                break
                
            else
                echo "  ${COLOR_RED}Incorrect choice, your selection out of range!!${COLOR_CLOSE}"
                echo 
                continue
            fi
        
        # multi key like 1,2,3
        elif [ `echo $ANS | awk -F',' '{print NF}'` -ge 2 ]; then
        
            # calc the error number
            starter=0
            
            # loop to check
            for j in `echo $ANS | sed 's/,/ /g'`; do
            
                # check is number
                if [ -n "`echo $j | tr -d "0-9"`" ]; then
                    echo "  ${COLOR_RED}[$j]: Incorrect choice, please input NUMBER >0!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi
                
                # must >0
                if [ $j -eq 0 ]; then
                    echo "  ${COLOR_RED}Incorrect choice, 0 is not allowd!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi
                
                # check value in range 
                if [ "$j" -gt "${#ALL_AVAIL_SELECT[*]}" ]; then
                    echo "  ${COLOR_RED}[$j]: Incorrect choice, your selection out of range!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi 
                
                # out value
                this_value="$this_value ${ALL_AVAIL_SELECT[j-1]}"
                
                
            done
            
            # has error
            if [ $starter -gt 0 ]; then
                unset $VARIABLE
                continue
            else
                # del space
                eval $VARIABLE=`echo $ANS`
                eval $VALUE=\"$this_value\"

                break
            fi
        
        
        # multi key like 1-3
        elif [ `echo $ANS | awk -F'-' '{print NF}'` -eq 2 ]; then
            # calc the error number
            starter=0
            
            # loop to check
            for j in `echo $ANS | sed 's/-/ /g'`; do
            
                # check is number
                if [ -n "`echo $j | tr -d "0-9"`" ]; then
                    echo "  ${COLOR_RED}[$j]: Incorrect choice, please input NUMBER >0!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi
                
                # must >0
                if [ $j -eq 0 ]; then
                    echo "  ${COLOR_RED}Incorrect choice, 0 is not allowd!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi
                
                # check value in range 
                if [ "$j" -gt "${#ALL_AVAIL_SELECT[*]}" ]; then
                    echo "  ${COLOR_RED}[$j]: Incorrect choice, your selection out of range!!${COLOR_CLOSE}"
                    echo
                    starter=$((starter + 1))
                    continue
                fi 
                
                
            done
        
        
            # check the range
            num_begin=`echo $ANS | awk -F'-' '{print $1}'`
            num_end=`echo $ANS | awk -F'-' '{print $2}'`
            
            # num_end must bigger
            if [ $num_end -lt $num_begin ]; then
                echo "  ${COLOR_RED}Please input a valid number range!!${COLOR_CLOSE}"
                echo
                starter=$((starter + 1))
            fi
            
            
            # has error
            if [ $starter -gt 0 ]; then
                unset $VARIABLE
                continue
            else
                
                # out value
                for k in `seq $num_begin $num_end`; do
                    this_value="$this_value ${ALL_AVAIL_SELECT[k-1]}"
                done
                
                # duplicate removal
                #this_value=`echo $this_value | xargs -n1 | uniq`
                
                eval $VARIABLE=`echo $ANS`
                eval $VALUE=\"$this_value\"
                
                break
            fi
        
        
        # wrong input
        else
            echo "  ${COLOR_RED}Incorrect choice, please follow the rules!!${COLOR_CLOSE}"
            echo 
            continue
        
        fi
        
        
    done

    
}


#############################################################################
# 作用: 给用户选择 Y or N, Y 则break ，N退出
# 用法: Ask_Y_Or_N
# 注意: 和Prompt_Yes_Or_No区别：Prompt_Yes_Or_No 先Y则，选N为继续，不会退出
#############################################################################
Ask_Y_Or_N(){
if [ $# -ne 1 ];then
    echo "Function Ask_Y_Or_N() is error!!"
    exit 100
else
    QUESTION=$1
    while true;do
        echo
        echo -en "  ${QUESTION} [Y/N]: "
        read ANS 
        case ${ANS} in
            N|n)exit 0;
            ;;
            Y|y)echo;echo;break;
            ;;
            *)echo "  ${COLOR_RED}Incorrect choice!!${COLOR_CLOSE}";continue;
        esac
    done
fi
}


#############################################################################
# 作用：提示用户是否继续, 如果继续，进入<YES_FUNCTION>; 否则<NO_FUNCTION>
# Prompt_Yes_Or_No <QUESTION>
# 注意：
#############################################################################
Prompt_Yes_Or_No() { 

    question=${1:-"Is the preceding information correct?"}
    
    while true;do
    echo -ne "  $question: [y/n default:n]: "
    #read -n1 ANS
    read ANS
    ANS=${ANS:0:1}
    case ${ANS} in
    #        N|n)EditMenu;
    #        ;;
    #        E|e)EditMenu;
    #        ;;
            N|n)echo;echo;exit 0;
            ;;
            Y|y)echo;echo;break;
            ;;
              *)echo;echo;continue;
    esac
    done

}



#############################################################################
# 作用: 根据用户输入的IP range格式，返回IP数量, 同时也可以判断用户的IP段是否正确
# 方法: Get_IP_Range <IPstart-IPend>
# 注意:  
#############################################################################
Get_IP_Number() {
    if [ `echo $1 | awk -F"-" '{print NF}'` -ne 2 ];then
        return 1
    fi
    
    IP_RANGE_FIRST=`echo $1 | awk -F"-" '{print $1}'`
    IP_RANGE_SECOND=`echo $1 | awk -F"-" '{print $2}'`
    
    if ! ipcalc -c $IP_RANGE_FIRST >/dev/null 2>&1;then
        return 1
    elif ! ipcalc -c $IP_RANGE_SECOND >/dev/null 2>&1;then
        return 1
    fi

    # If the avail IP address less than value define in cloud_product.conf
    B_NETWORK_FIRST=`echo $IP_RANGE_FIRST | cut -d'.' -f1`
    B_NETWORK_SECOND=`echo $IP_RANGE_FIRST | cut -d'.' -f2`
    B_NETWORK_THIRD=`echo $IP_RANGE_FIRST | cut -d'.' -f3`
    B_NETWORK_FORTH=`echo $IP_RANGE_FIRST | cut -d'.' -f4`

    E_NETWORK_FIRST=`echo $IP_RANGE_SECOND | cut -d'.' -f1`
    E_NETWORK_SECOND=`echo $IP_RANGE_SECOND | cut -d'.' -f2`
    E_NETWORK_THIRD=`echo $IP_RANGE_SECOND | cut -d'.' -f3`
    E_NETWORK_FORTH=`echo $IP_RANGE_SECOND | cut -d'.' -f4`


    IP_NUMS=`expr $((16777216*10#$E_NETWORK_FIRST+65536*10#$E_NETWORK_SECOND+256*10#$E_NETWORK_THIRD+10#$E_NETWORK_FORTH-\
    16777216*10#$B_NETWORK_FIRST-65536*10#$B_NETWORK_SECOND-256*10#$B_NETWORK_THIRD-10#$B_NETWORK_FORTH))`

    Log DEBUG "network IP_NUMS is $IP_NUMS"
}


#############################################################################
# 作用: IP/掩码位数 的格式判断
# 方法: Check_Network_Range <ANS>
# 注意: 
#############################################################################
Check_Network_ShortRange() {
    if [ `echo $ANS | awk -F"/" '{print NF}'` -ne 2 ];then
        return 1
    fi
    ip_first=`echo $ANS | awk -F"/" '{print $1}'`
    ip_second=`echo $ANS | awk -F"/" '{print $2}'`

    if [ ! -z "`echo "$ip_second" | tr -d '[0-9]'`" ]; then 
        return 1
    fi

    if ! ipcalc -c $ip_first >/dev/null 2>&1;then
        Log WARN "not ip format"
        return 1
    elif [ "$ip_second" -gt 32 ];then
        Log WARN "cdr out of range"
        return 1
    fi


}





#############################################################################
# 作用：IP地址+掩码 计算出网络号
# 方法: IP_Mask_To_Network <IPADDR> <NETMASK>
# 注意: 更简单的方法, 见ip_calc.sh
#############################################################################
IP_Mask_To_Network() {

    if [ "$#" -ne 2 ]; then
        Log ERROR "Function IP_Mask_To_Network() error! Usage: IP_Mask_To_Network <IPADDR> <NETMASK>\n"
    fi
    
    ipaddr=$1
    netmask=$2
    
    # The easyest way
    
    # eval $(ipcalc -np 192.168.2.203 255.255.255.0)
    # $NETWORK=192.168.2.0 PREFIX=24
    
    
    # use the follow, very clear~~
    # $ IFS=. read -r i1 i2 i3 i4 <<< "192.168.1.15"
    # $ IFS=. read -r m1 m2 m3 m4 <<< "255.255.0.0"
    # $ printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
    # 192.168.0.0
    
    net_first=`echo $ipaddr | cut -d'.' -f1`
    net_second=`echo $ipaddr | cut -d'.' -f2`
    net_third=`echo $ipaddr | cut -d'.' -f3`
    net_fourth=`echo $ipaddr | cut -d'.' -f4`
    mask_first=`echo $netmask | cut -d'.' -f1`
    mask_second=`echo $netmask | cut -d'.' -f2`
    mask_third=`echo $netmask | cut -d'.' -f3`
    mask_fourth=`echo $netmask | cut -d'.' -f4`
    ((net_first=net_first&mask_first))
    ((net_second=net_second&mask_second))
    ((net_third=net_third&mask_third))
    ((net_fourth=net_fourth&mask_fourth))
    network=$net_first.$net_second.$net_third.$net_fourth
    
    echo $network

}

#############################################################################
## from: http://stackoverflow.com/   netmask2cdir and cdir2netmask

# 作用：掩码换算成CDR
# 方法: Mask_To_CDR <NETMASK>
# 注意: 更简单的方法, 见ip_calc.sh
#############################################################################
Mask_To_CDR() {

    # Assumes there's no "255." after a non-255 byte in the mask
    local x=${1##*255.}
    set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
    x=${1%%$3*}
    echo $(( $2 + (${#x}/4) ))
}




#############################################################################
## from: http://stackoverflow.com/   netmask2cdir and cdir2netmask

# 作用：CDR换算成掩码
# 方法: CDR_To_MASK <CDR>
# 注意: 
#############################################################################
CDR_To_MASK() {
    # Number of args to shift, 255..255, first non-255 byte, zeroes
    set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
    [ $1 -gt 1 ] && shift $1 || shift
    echo ${1-0}.${2-0}.${3-0}.${4-0}

}


#############################################################################
# 作用: 提示用户输入答案
# 方法: Ask_Question <QUESTION> <VARIABLE> <ANSWER_CHECK_FUNCTION>
# 注意: 
#############################################################################
Ask_Question() {
    if [ $# -lt 2 ];then
        Log ERROR "Function Ask_Question() error!!"
    fi
    QUESTION="$1"
    VARIABLE="$2"
    ANSWER_CHECK_TYPE="$3"
    FIRST=0
    while true;do
        FIRST=$(($FIRST+1))
        if [ $FIRST -le 1 ]; then
            if [ -n "${!VARIABLE}" ]; then
                echo -en "  $QUESTION [default:${!VARIABLE}]: "
            else
                echo -en "  $QUESTION: "
            fi
        else
            echo "  ${COLOR_RED}Your input \"$ANS\" is invalid!${COLOR_CLOSE}"
            echo
            if [ -n "${!VARIABLE}" ]; then
                echo -en "  $QUESTION [default:${!VARIABLE}]: "
            else
                echo -en "  $QUESTION: "
            fi
        fi    
        read ANS; 
        if [ -n "$ANS" ]; then
        
            if [ -n "$ANSWER_CHECK_TYPE" ]; then
                ANSWER_CHECK_FUNCTION="Checker $ANSWER_CHECK_TYPE $ANS"
            else
                ANSWER_CHECK_FUNCTION=true
            fi
            
            if $ANSWER_CHECK_FUNCTION; then
                #eval $VARIABLE=`echo $ANS | tr ' |' ','`
                eval $VARIABLE=\"$ANS\"
                break
            else
                unset ${VARIABLE}
                continue
            fi
        else
            ANS="${!VARIABLE}"
            if [ -n "$ANS" ]; then
                if [ -n "$ANSWER_CHECK_TYPE" ]; then
                    ANSWER_CHECK_FUNCTION="Checker $ANSWER_CHECK_TYPE $ANS"
                else
                    ANSWER_CHECK_FUNCTION=true
                fi
            else
                continue
            fi
            
            if $ANSWER_CHECK_FUNCTION; then
                break
            fi
        fi
    done
}


#############################################################################
# 作用：提示用户输入项，并将值传给指定的变量；使用变量的值做为默认值
# 使用方法：Prompt_Input <VARIABLE> <CHECK_FUNCTION> <PROMPT_INFORMATION>
# 注意：
#############################################################################
Prompt_Input() { 
    if [ "$#" -ne 3 ]; then
        echo -e "   Function Prompt_Input() error! Usage: Prompt_Input <VARIABLE> <PROMPT_INFORMATION>\n"
        exit 250
    fi
    
    variable=$1
    check_function=$2
    prompt_information=$3
    
    FIRST=0
    while true;do
        FIRST=$(($FIRST+1))
        echo
        if [ $FIRST -le 1 ]; then
            echo -en "   $prompt_information [default:${!variable}]: "
        else
            echo -e "   ${COLOR_RED}Your input \"$ANS\" is invalid!${COLOR_CLOSE}"
            echo -n "   $prompt_information [default:${!variable}]: "
        fi    
        read ANS; 
        if [ -n "$ANS" ]; then
            if $check_function; then
                eval $variable=`echo $ANS | tr ' |' ','`
                break
            else
                continue
            fi
        else
            ANS="${!variable}"
            if $check_function; then
                break
            fi
        fi
    done

}


#############################################################################
# 作用：显示已输入
# 用法: Show_Input
# 注意: 
#############################################################################
Show_Input() {
    echo
    echo -n "  |-------------------------------------------------------------------"
    echo -ne "\e[6n";read -sdR pos0;pos0=${pos0#*[};P0=${pos0/;/ };L0=${P0%% *};C0=${P0##* }
    echo
    echo -n "  |------------------ "
    echo -n "${BOLD}Input HOST information...${NORMAL}"
    echo " ----------------------"
    
    show_content=`echo $this_value_list | xargs -n1 | nl | sed 's/^/  |  /g' | tr ',' '\t'`
    
    cat <<EOF
  |
  |       ID  RACK_ID       IP          USER    PASSWORD
  |
$show_content
  |
  |
  |
  |
EOF
    echo -n "  |-------------- Press \"y\" to continue, \"r\" to re-input-------------"
    echo -ne "\e[6n";read -sdR pos1;pos1=${pos1#*[};P1=${pos1/;/ };L1=${P1%% *};C1=${P1##* }
    for ((i=$L1;i>=L0;i--));do
        tput cup `expr $i - 1` `expr $C1 - 1`;echo "|"
    done
    echo -e "\\033[$((L1));$((C1))H"

    while true;do
    echo -n "  Is the preceding information correct? [r/y default:y]: "
    
    read -n1 ANS
    ANS=${ANS:0:1}
    
    case ${ANS} in
            r|R)echo; Ask_Question_About_Host_Single;
            ;;
            Y|y|"")break;
            ;;
              *)echo;echo;continue;
    esac
    done
}


#############################################################################
# 作用：打印用户输入的内容
# 用法: Show_Confirm
# 注意: 
#############################################################################
Show_Confirm(){
    clear
    echo
    echo -e "   Here are the products installation information:"
    echo -e "   ---------------------------------------------------------------"
    echo -e "   FULL  DOMAIN:\t\t${FULL_DOMAIN}"
    echo -e "   SHORT DOMAIN:\t\t${SHORT_DOMAIN}"
    
    # if [ -n "${VM_ALREADY_INSTALLED_NAME_AND_IP_SET[*]}" ]; then
        # echo -e "   VM already installed:"
        # for ((i=0; i<${#VM_ALREADY_INSTALLED_NAME_AND_IP_SET[*]}; i++)); do
            # i_name=`echo ${VM_ALREADY_INSTALLED_NAME_AND_IP_SET[i]} | awk -F',' '{print $1}'`
            # i_ip=`echo ${VM_ALREADY_INSTALLED_NAME_AND_IP_SET[i]} | awk -F',' '{print $2}'`
            # echo -e "   ---${i_name} with IP:\t\t${i_ip}"
        # done
    # fi

    
    echo -e "   Server number:\t\t`echo ${host_content} | wc -w`"
    echo -e "   MON hosts:\t\t\t`echo ${mon_value} | wc -w`"
    echo -e "   OSD hosts:\t\t\t`echo ${osd_value} | wc -w`"
    echo -e "   MDS hosts:\t\t\t`echo ${mds_value} | wc -w`"

    if echo ${PORDUCT_TO_BE_INSTALLED[*]} | grep -qw "CLOUD_STACK"; then
        echo
        echo -e "   VM Fixed    Range for cloud:\t\t$VM_NETWORK_RANGE"
        echo -e "   VM Floating Range for cloud:\t\t$VM_FLOATING_RANGE"
    fi
    
    echo -e "   ---------------------------------------------------------------"
    while true; do
        echo
        echo -n "   Are you sure to continue? [y=yes, r=return, q=quit]: "
        read ANS
        ANS=${ANS:0:1}
        
        case ${ANS} in
            Y|y) 
                # echo the value to file, to use later
                cat <<EOF >${TMP_DIR}/${DIALOG_ANS_FILE_TMP}
$domain_content
$host_content_real
$role_content_select
    cluste_network="$cluste_network"
    mon_selection="$mon_selection"
    osd_selection="$osd_selection"
    mds_selection="$mds_selection"
EOF
            
            break; 
            ;;
            R|r) clear; Dialog_Question
            ;;
            Q|q) exit 0
            ;;
            *) continue
            ;;
        esac
    done
}


#############################################################################
# 作用：确保每个Rack节点数量不超过48个
# 用法: Check_Node_Per_Rack
# 注意: 
#############################################################################
Check_Node_Per_Rack(){

    Log -n DEBUG "basic rack and host check"
    host_content=`INI_Parser ${TMP_DIR}/${DIALOG_ANS_FILE} host`
    hosts_per_rack_max=48
    
    if [ `echo "$host_content" | wc -l` -le $hosts_per_rack_max ]; then
        Log DEBUG "passed"
        return 0
        
    else
    
        # get the hosts count for every rack
        rack_uniq=`echo "$host_content" | awk -F'=' '{print $2}' | awk -F'|' '{print $1}' | tr -d '"' | sort | uniq`
        for r in $rack_uniq; do
            if [ `echo "$host_content"  | grep $rack_uniq | wc -l` -gt $hosts_per_rack_max ]; then
                Log ERROR "rack id: $r has reachd to $hosts_per_rack_max hosts"
            fi
        done
    fi

}



######################################################################
# 作用: 通过短 域名 + RACK名 + IP + IP域名对应表, 存储到 I_HOSTNAME
# 用法: Gen_HostName <SHORT_DOMAIN> <RACK_NUM> <IP> <RACK_IP_FILE>
# 注意：IP决定排名，如果IP在前，则节点主机名前, 主机名格式: sc1r01n01
# ++ sc1: shencloud first data center;  r01: rack01;  n01:  node01
######################################################################
Gen_Hostname() {
    
    if [ $# -ne 4 ]; then
        Log ERROR "Function Gen_Hostname() error! Usage: Gen_Hostname <SHORT_DOMAIN> <RACK_NUM> <IP> <RACK_IP_FILE>\n"
    fi
    
    Log DEBUG "change the temp hostname to intelligence hostname"
       
    unset I_HOSTNAME
       
    short_domain=$1
    rack_num=$2
    ip_addr=$3
    rack_ip_file=$4
    
    
    # domain length less than 4, yes, it is 4, not 5, test wc -c
    if [ `echo $short_domain | wc -c` -gt 5 ]; then
        Log ERROR "short domain must less than 4"
    fi
    
    # rack_num must be number
    if ! Checker is_allnum $rack_num; then
        Log ERROR "rack_number must be numerical"
    fi
    
    # ip_addr check
    if ! Checker is_ip $ip_addr; then
        Log ERROR "IP addr must be ip format"
    fi
    
    [ -f "$rack_ip_file" ] || Log ERROR "RACK_IP_FILE not found"
    
    # get the all ip in this rack, sort by number
    all_ip_of_this_rack_sorted=`INI_Parser $rack_ip_file host | awk -F'=' '{print $2}' |\
    awk -F'|' '{print $2}' | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 | nl | xargs -n 2 | awk '{if ($1<10); print 0$1"  "$2}'`
        
    #echo -e "all_ip_of_this_rack_sorted is\n$all_ip_of_this_rack_sorted"
    
    # get this ip number
    this_ip_number=`echo "$all_ip_of_this_rack_sorted" | grep -w "$ip_addr" | awk '{print $1}'`
    
    [ -z "$this_ip_number" ] && Log ERROR "can not get ip number"
    
    # out hostname
    I_HOSTNAME="${short_domain}r${rack_num}n${this_ip_number}"
    
}


######################################################################
# 作用: 将ANS内的host_xx修改为真实的hostname
# 用法: ANS_File_Update_Hostname
# 注意：
######################################################################
ANS_File_Update_Hostname(){ 
        
    old_ans_file=${TMP_DIR}/${DIALOG_ANS_FILE}
    new_ans_file=${RUN_DIR}/${DIALOG_ANS_FILE_FINAL}

    Log DEBUG "updating ans file to ${new_ans_file}"
    
    # get the ans content
    short_domain=`INI_Parser $old_ans_file domain SHORT_DOMAIN`
    host_content=`INI_Parser $old_ans_file host`
    role_content=`INI_Parser $old_ans_file role`
    
    #echo -e "host_content is\n$host_content"
    
    # copy to run dir
    cp -rLfap $old_ans_file $new_ans_file
    

    # loop the host content
    
    for line in $host_content; do
        
        # skip content that start with '#'
        if echo $line | grep -q "^ *#"; then
            continue
        fi
        
        tmp_hostname=`echo $line | awk -F'=' '{print $1}'`
        rack_name=`echo $line | awk -F'=' '{print $2}' | awk -F'|' '{print $1}'`
        rack_num=${rack_name#rack}
        this_ip=`echo $line | awk -F'=' '{print $2}' | awk -F'|' '{print $2}'`
        clu_network=
        
        # gen real hostname
        if [ -f ${RUN_DIR}/${HOSTNAME_USER_DEFINE_FILE} ]; then
        
            # if user define this hostname
            if grep -wq $this_ip ${RUN_DIR}/${HOSTNAME_USER_DEFINE_FILE}; then
                I_HOSTNAME=`grep -v "^ *#" ${RUN_DIR}/${HOSTNAME_USER_DEFINE_FILE} | grep -w $this_ip  | awk '{print $2}'`
                
                Log WARN "using user define hostname $I_HOSTNAME for ip $this_ip"
                
            else
                Gen_Hostname $short_domain $rack_num $this_ip $old_ans_file
            
            fi
        else
        
            Gen_Hostname $short_domain $rack_num $this_ip $old_ans_file
        fi
        
        # check hostname
        Checker is_hostname $I_HOSTNAME
        
        Log DEBUG "IP: $this_ip -> HOSTNAME: $I_HOSTNAME"

        # replace the tmp_hostname to this_hostname
        sed -i "s/$tmp_hostname/$I_HOSTNAME/" ${new_ans_file}
        

    done

    
    
    
    # re-get host_content
    host_content=`INI_Parser $new_ans_file host`
        
    # TODO: loop the role content(no necessary)
    while read line ; do
        
        # skip content that start with '#'
        if echo $line | grep -q "^ *#"; then
            continue
        fi
        
        role=`echo $line | awk -F'=' '{print $1}'`
        
        for j in `echo $line | awk -F'=' '{print $2}' | tr -d '"'`; do
            replaced_value=`echo "$host_content" | grep -w "$j" | awk -F'=' '{print $1}'`
            sed -i "/$role/s/$j/$replaced_value/" $new_ans_file
        
        done
        
    done <<< "$role_content"

    Log DEBUG "update success"
    Log DEBUG ""
}



######################################################################
# 作用: 获取所有主机的掩码信息, 并更新至ans.run中; 同时生成每个主机的cluster ip
# 用法: ANS_Update_Netmask
# 注意：
######################################################################
ANS_Update_Network() {

    ans_file=${RUN_DIR}/${DIALOG_ANS_FILE_FINAL}

    Log -n DEBUG "update network mask to $ans_file"
    ip_offset=1
    for i in $HOST_CONTENT; do
    
        this_hostname=`echo $i | awk -F'=' '{print $1}'`
        ipaddr_mask=`echo $i | awk -F'=' '{print $2}' | tr -d '"' | awk -F'|' '{print $2}'`
        ipaddr=`echo $i | awk -F'=' '{print $2}' | tr -d '"' | awk -F'|' '{print $2}' | awk -F',' '{print $1}'`
        
        clu_network=`echo $i | awk -F'=' '{print $2}' | tr -d '"' | awk -F'|' '{print $3}' | awk -F',' '{print $1}'`
        clu_mask=`echo $i | awk -F'=' '{print $2}' | tr -d '"' | awk -F'|' '{print $3}' | awk -F',' '{print $2}'`
        
        this_netinfo=`ssh -o StrictHostKeyChecking=no -q $this_hostname "ip a | grep -w $ipaddr"`
        this_mask_cdr=`echo $this_netinfo | awk '{print $2}' | awk -F'/' '{print $2}'`
        this_mask=`CDR_To_MASK $this_mask_cdr`
        
        # add netmask
        #Log DEBUG "change $ipaddr_mask to $ipaddr,$this_mask in $ans_file"
        sed -i "/$this_hostname/s/\<$ipaddr_mask\>/$ipaddr,$this_mask/" $ans_file
        
        
        ## update the cluster network 
        # calc the clu_network start...end
        network_calc=`${LIB_DIR}/net/ipcalc.pl ${clu_network}/${clu_mask}`
        host_min=`echo "$network_calc" | grep HostMin | awk '{print $2}'`
        host_max=`echo "$network_calc" | grep HostMax | awk '{print $2}'`
        
        # get the network part
        IFS=. read -r i1 i2 i3 i4 <<< $host_min
        IFS=. read -r m1 m2 m3 m4 <<< $host_max


        # ip to int
        # import the external library to calc numic network
        . ${LIB_DIR}/net/ip_calc.sh
        
        ipf4_start=$i4
        ipf4_end=$m4
        
        ip2int_start=`ip2int $host_min`
        ip2int_end=`ip2int $host_max`
        
        let ip2int_start=$ip2int_start+$ip_offset
        
        # get a valid ip
        while [ $ip2int_start -lt $ip2int_end ]; do
            
            unset this_clu_ip
        
            # re-pack the numic ip
            this_ip=`int2ip $ip2int_start`
            
            # check this_ip
            IFS=. read -r t1 t2 t3 t4 <<< $this_ip
        
            # if not in range
            if [ $t4 -lt $ipf4_start -o $t4 -gt $ipf4_end ]; then
            
                # shift
                let ip2int_start=$ip2int_start+1
                continue
                
            # if in range, then offset + 1    
            else
                let ip_offset=$ip_offset+1
                this_clu_ip=$this_ip
                break
            fi
        
        done
        
        [ -z "$this_clu_ip" ] && Log ERROR "calc the cluster ip error"
        
        
        # change this_clu_ip
        sed -i "/$this_hostname/s/\<$clu_network\>/$this_clu_ip/" $ans_file
        
    done
    
    Log DEBUG "success"

}


######################################################################
# 作用: 取出${RUN_DIR}/$DIALOG_ANS_FILE_FINAL 里的基本一些值
# 用法: ANS_Basic_Value_Get
# 注意：因为后面还会更新此文件，后面 ANS_Advanced_Value_Get 会继续取其它
######################################################################
ANS_Basic_Value_Get(){ 
    
    ans_file=${RUN_DIR}/$DIALOG_ANS_FILE_FINAL
    
    FULL_DOMAIN=`INI_Parser $ans_file domain FULL_DOMAIN`
    SHORT_DOMAIN=`INI_Parser $ans_file domain SHORT_DOMAIN`
    
    DOMAIN_CONTENT=`INI_Parser $ans_file domain`
    HOST_CONTENT=`INI_Parser $ans_file host`
    ROLE_CONTENT=`INI_Parser $ans_file role`
    
    ALL_HOST=`echo "$HOST_CONTENT" | awk -F'=' '{print $1}' | xargs`


}



######################################################################
# 作用: 取出${RUN_DIR}/$DIALOG_ANS_FILE_FINAL 里的所有用到的值
# 用法: ANS_Advanced_Value_Get
# 注意：因为后面还会更新此文件，后面ANS_Advanced_Value_Get 会继续取其它
######################################################################
ANS_Advanced_Value_Get(){ 
    
    # re-get once again
    ans_file=${RUN_DIR}/$DIALOG_ANS_FILE_FINAL
    
    FULL_DOMAIN=`INI_Parser $ans_file domain FULL_DOMAIN`
    SHORT_DOMAIN=`INI_Parser $ans_file domain SHORT_DOMAIN`
    
    DOMAIN_CONTENT=`INI_Parser $ans_file domain`
    HOST_CONTENT=`INI_Parser $ans_file host`
    ROLE_CONTENT=`INI_Parser $ans_file role`
    
    ALL_HOST=`echo "$HOST_CONTENT" | awk -F'=' '{print $1}' | xargs`
    
    MON_HOST=`echo "$ROLE_CONTENT" | grep "MON=" | awk -F'=' '{print $2}' | xargs`
    OSD_HOST=`echo "$ROLE_CONTENT" | grep "OSD=" | awk -F'=' '{print $2}' | xargs`
    MDS_HOST=`echo "$ROLE_CONTENT" | grep "MDS=" | awk -F'=' '{print $2}' | xargs`
    
    MON_HOST_LIST=`echo $MON_HOST | tr ' ' ','`

    MON_IPADDR_PUBLIC=`for i in $MON_HOST; do grep -w $i <<<"$HOST_CONTENT" | awk -F'=' '{print $2}' | \
    tr -d '"' | awk -F'|' '{print $2}' | awk -F',' '{print $1}'; done | xargs`

    MON_IPADDR_CLUSTER=`for i in $MON_HOST; do grep -w $i <<<"$HOST_CONTENT" | awk -F'=' '{print $2}' | \
    tr -d '"' | awk -F'|' '{print $3}' | awk -F',' '{print $1}'; done | xargs`
    

    # Mon PUBLIC netmask (use first netmask)
    MON_NETMASK_PUBLIC=`for i in $MON_HOST; do grep $i <<<"$HOST_CONTENT" | awk -F'=' '{print $2}' | \
    tr -d '"' | awk -F'|' '{print $2}' | awk -F',' '{print $2}'; done | xargs | awk '{print $1}'`

    # calc the PUBLIC cdr
    MON_NETMASK_PUBLIC_CDR=`Mask_To_CDR $MON_NETMASK_PUBLIC`
    

    # Mon CLUSTER netmask (use first netmask)
    MON_NETMASK_CLUSTER=`for i in $MON_HOST; do grep $i <<<"$HOST_CONTENT" | awk -F'=' '{print $2}' | \
    tr -d '"' | awk -F'|' '{print $3}' | awk -F',' '{print $2}'; done | xargs | awk '{print $1}'`
    
    # calc the CLUSTER cdr
    MON_NETMASK_CLUSTER_CDR=`Mask_To_CDR $MON_NETMASK_CLUSTER`

    # CEPH_MON_PORT in "setting.conf"
    MON_IPADDR_PORT=`for i in $MON_IPADDR_PUBLIC; do echo $i:${CEPH_MON_PORT}; done | xargs | tr ' ' ','`
    

    # public network use ip & netmask calc
    PUBLIC_FIRST_IPADDR=`echo $MON_IPADDR_PUBLIC | awk '{print $1}'`
    CLUSTER_FIRST_IPADDR=`echo $MON_IPADDR_CLUSTER | awk '{print $1}'`
    
    # calc the public/cluster network/cdr
    PUBLIC_NETWORK=`IP_Mask_To_Network $PUBLIC_FIRST_IPADDR $MON_NETMASK_PUBLIC`/$MON_NETMASK_PUBLIC_CDR
    CLUSTER_NETWORK=`IP_Mask_To_Network $CLUSTER_FIRST_IPADDR $MON_NETMASK_CLUSTER`/$MON_NETMASK_CLUSTER_CDR
    
        
}



######################################################################
# 作用: 提示用户输入domain信息
# 用法: Ask_Question_About_Domain
# 注意：
######################################################################
Ask_Question_About_Domain(){ 

    [ -f ${TMP_DIR}/${DIALOG_ANS_FILE_TMP} ] && Importer ${TMP_DIR}/${DIALOG_ANS_FILE_TMP}
    
    echo
    Log DEBUG "STEP1 --- 请输入域名相关信息:"
    # full domain
    Ask_Question "Please input the ${BOLD}完整域名${NORMAL} information，eg: shencloud.org" FULL_DOMAIN  is_domain
    echo
    # short domain
    Ask_Question "Please input the ${BOLD}项目简称${NORMAL} information, eg: sc1" SHORT_DOMAIN  is_shortdomain


    domain_content="FULL_DOMAIN=$FULL_DOMAIN  SHORT_DOMAIN=$SHORT_DOMAIN"

    domain_content=`echo $domain_content | xargs -n1 | sed 's/^/    /'`
    
}


######################################################################
# 作用: 提示用户输入host信息(单服务器输入)
# 用法: Ask_Question_About_Host_Single
# 注意：
######################################################################
Ask_Question_About_Host_Single(){ 
    
    clear
    starter=1
    unset this_host_list 
    unset this_value_list
    echo
    Log DEBUG "共三步: 1. 输入域名相关信息.  2. ${SMSO}输入主机网络相关信息${NORMAL}  3. 选择CEPH组件所在host"
    echo
    Log DEBUG "STEP2.1 --- 输入主机网络相关信息:"
    Log DEBUG "请按下面要求进行输入, 如果输入完成, 请键入\"ok\""
    Log DEBUG "This is single mode, to change batch mode, input \"batch\""
    Log DEBUG "进入蛋疼输入模式, 如要删除, 请按住CTRL, 或按\"CTRL+W\"或\"CTRL+U\""
    
    while true; do
        
        # host info
        echo
        Ask_Question "Please input the ${BOLD}机架ID|主机IP|用户名|密码${NORMAL} information, eg: 01|192.168.120.245|root|password\n \
 tips: 机架ID必须为数字, 如输入完毕, 键入\"ok\"" tmphost${starter}

        this_key="tmphost${starter}"
        this_value=${!this_key}
        
        # at least one host require
        if [ "$this_value" = "ok" ]; then
        
            # if first prompt
            if [ -z "$this_value_list" ]; then
                # if no input 
                if [ "$tmphost1" = "ok" ]; then
                    Log WARN "至少得加一台服务器信息再退出吧, 小样~"
                    continue
                fi
            else
                # show the $this_value_list
                Show_Input
                break
            fi
            
        fi
        
        
        
        # change mode
        [ "$this_value" = "batch" ] && Ask_Question_About_Host_Batch
        
        # note: Ask_Question will change separate "|" to ","
        this_rack=`echo $this_value | awk -F'|' '{print $1}'`
        this_ip=`echo $this_value | awk -F'|' '{print $2}'`
        this_user=`echo $this_value | awk -F'|' '{print $3}'`
        this_pass=`echo $this_value | awk -F'|' '{print $4}'`
        

        # zero check
        if [ -z "$this_rack" -o -z "$this_ip" -o -z "$this_user" -o -z "$this_pass" ]; then
            if [ -z "$this_value" ]; then
                Log WARN "请按要求输入" && continue
            fi
        fi
        
        
        # check value
        Checker is_allnum $this_rack && Checker is_ip $this_ip && Checker is_username $this_user && Checker is_password $this_pass || continue
        
        # check for dup
        if echo "$this_host_list" | grep -q "$this_ip"; then
            Log WARN "已经有重复的IP" && continue
        fi
        
        Log DEBUG "已成功输入${COLOR_GREEN}$starter${COLOR_CLOSE}条主机信息"
        
        # to use "history"
        this_value_list="$this_value_list $this_value"
        
        # to host_content use 
        this_host_list="$this_host_list $this_key=$this_value"
        
        starter=$((starter + 1))
    done

    
    Draw_Line 80%
    
    # ask for cluster network
    clear
    unset host_content
    unset host_content_real
    while true; do
        echo
        Log DEBUG "共三步: 1. 输入域名相关信息.  2. ${SMSO}输入主机网络相关信息${NORMAL}  3. 选择CEPH组件所在host"
        echo
        Log DEBUG "STEP2.2 --- 输入集群内部IP:"
        Ask_Question "Please input the ${BOLD}CEPH集群内部复制网络${NORMAL} information, eg: 192.168.88.0/24 或者 192.168.88.0/255.255.255.0\n \
 tips: 这个网络使用内部万M交换, ${COLOR_YELLOW}不能${COLOR_CLOSE}和上面输入的网络同网段" cluste_network 
        unset this_ip
        this_ip=`echo $cluste_network | awk -F'/' '{print $1}'`
        cdr_or_mask=`echo $cluste_network | awk -F'/' '{print $2}'`
        
        [ -z "$cdr_or_mask" -o -z "$this_ip" ] && Log WARN "请按要求输入" && continue
        
        # check ip
        Checker is_ip $this_ip || continue
        clu_network=$this_ip
        
        # check mask or cdr
        if [ `echo $cdr_or_mask | awk -F'.' '{print NF}'` -eq 4 ]; then
            # mask mode
            if Checker is_ip $cdr_or_mask; then
                clu_mask=$cdr_or_mask
                break
            else
                continue
            fi
            
        # cdr mode    
        elif Checker is_allnum $cdr_or_mask; then
            
            if Check_Network_ShortRange $cluste_network; then
                # cdr to mask
                clu_mask=`CDR_To_MASK $cdr_or_mask`
                break
            else
                continue
            fi
            
        else
            Log WARN "请按要求输入" && continue
        fi
    
    done
    
    
    # the full host content($this_host_list + clu_network,clu_mask)
    for i in $this_host_list; do
        this_tmp_hostname=`echo $i | awk -F'=' '{print $1}'`
        this_rack=`echo $i | awk -F'=' '{print $2}' | awk -F'|' '{print $1}'`
        this_ip=`echo $i | awk -F'=' '{print $2}' | awk -F'|' '{print $2}'`
        this_user=`echo $i | awk -F'=' '{print $2}' | awk -F'|' '{print $3}'`
        this_pass=`echo $i | awk -F'=' '{print $2}' | awk -F'|' '{print $4}'`
        
        
        # make host_content
        host_content="$host_content  $this_tmp_hostname=\"rack${this_rack}|${this_ip}|${clu_network},${clu_mask}|${this_user}|${this_pass}\""
        host_content_real="$host_content_real  $this_tmp_hostname=\"${this_rack}|${this_ip}|${this_user}|${this_pass}\""
    done
    
    host_content=`echo $host_content | sed  's/ /\n/g' | sed 's/^/    /'`
    host_content_real=`echo $host_content_real | sed  's/ /\n/g' | sed 's/^/    /'`
}




######################################################################
# 作用: 提示用户输入host信息(批量服务器输入)
# 用法: Ask_Question_About_Host_Batch
# 注意：
######################################################################
Ask_Question_About_Host_Batch(){ 
    
        # pormat the information
        clear
        echo
        Log DEBUG "This is batch mode"
        Log DEBUG "为了简化操作, 在开始安装前, 请先将所有的服务器设置为相同的用户名密码"
        Log DEBUG "如果需要使用单服务器输入模式，请输入\"single\""
        echo
        
        
    

}


######################################################################
# 作用: 提示用户输入role信息
# 用法: Ask_Selection_About_Role
# 注意：
######################################################################
Ask_Select_About_Role(){ 

    clear
    echo 
    unset all_value
    Log DEBUG "共三步: 1. 输入域名相关信息.  2. 输入主机网络相关信息  3. ${SMSO}选择CEPH组件所在host${NORMAL}"
    echo
    Log DEBUG "STEP3 --- 请选择CEPH组件所在host:\n  tips: 非连续多选请使用\",\"将数字选项隔开, 如"5,1,2,4"; 连续选项请用\"2-5\"的方式"
    
    for i in ${!tmphost*}; do
        all_value="$all_value ${!i}"
    done
    
    all_value=`echo $all_value | xargs -n1 | grep -v "ok" | grep -v "batch" | xargs`
    
    
    ## Ask for MON
    while true; do
        Ask_Select "${all_value}"  "3.1 please select the MON host(${BOLD}大于等于1的奇数个${NORMAL})"  mon_selection  mon_value
        
        # mon_value count must odd
        mon_value_count=`echo $mon_value | wc -w`
        
        # odd
        if [ $((mon_value_count % 2)) -eq 1 ]; then
            break
        else
            Log WARN "请选择大于等于1的奇数个主机"
            continue
        fi
    done
        
    # value change to ip value
    mon_value=`for i in $mon_value; do echo $i | awk -F'|' '{print $2}'; done`
    mon_value=`echo $mon_value`


    
    ## Ask for OSD 
    Ask_Select "${all_value}"  "3.2 please select the OSD host"  osd_selection   osd_value

    # value change to ip value
    osd_value=`for i in $osd_value; do echo $i | awk -F'|' '{print $2}'; done`
    osd_value=`echo $osd_value`
    
    
    ## Ask for MDS 
    Ask_Select "${all_value}"  "3.2 please select the MDS host"  mds_selection   mds_value

    # value change to ip value
    mds_value=`for i in $mds_value; do echo $i | awk -F'|' '{print $2}'; done`
    mds_value=`echo $mds_value`
    

    

}

######################################################################
# 作用: 生成ANS File
# 用法: Ask_Question_About_Role
# 注意：
######################################################################
Gen_Ans_File(){ 

    Log DEBUG "gen ans file to ${TMP_DIR}/${DIALOG_ANS_FILE_TMP}"
    cat <<EOF >${TMP_DIR}/${DIALOG_ANS_FILE}
# ANS file auto generate by Ceph_AI


[domain]

$domain_content


[host]

$host_content


[role]

    MON="$mon_value"
    OSD="$osd_value"
    MDS="$mds_value"

EOF


}



######################################################################
# 作用: 整个dialog封装, 然后输出至 $DIALOG_ANS_FILE
# 用法: Dialog_Question
# 注意：
######################################################################
Dialog_Question() {

    while true; do
        Log DEBUG "共三步: 1. ${SMSO}输入域名相关信息${NORMAL}.  2. 输入主机网络相关信息  3. 选择CEPH组件所在host"
        echo
        
        Ask_Question_About_Domain
        Draw_Line 80%
        
        
        # value set in style file
        if [ "$INPUT_MODE" = "single" ]; then
            Ask_Question_About_Host_Single
        else
            Ask_Question_About_Host_Batch
        fi
        Draw_Line 80%
        

        # select mon, osd, mds host
        Ask_Select_About_Role
        Draw_Line 80%
        
        
        # confirm
        Show_Confirm
        break
        
    done
}


######################################################################
# 作用: 检查并更新ANS file
# 用法: ANS_Check_And_Update
# 注意：
######################################################################
ANS_Check_And_Update() {

    # check ans vlaue
    [ -z "$domain_content" ] || [ -z "$host_content" ] || [ -z "$mon_value" ] || [ -z "$osd_value" ] || \
    [ -z "$mds_value" ] && Log ERROR "Dialog_Question must run first, please check"

    # gen ans.out
    Gen_Ans_File

    # every rack less than 48 server
    Check_Node_Per_Rack
    
    # gen ans.run
    ANS_File_Update_Hostname
}