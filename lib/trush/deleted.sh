# 作用：统一退出函数, 退出时清理显示环境, 并记录日志
# 使用方法：$EXIT <ERRORCODE>
# 注意：从errorcode中拿
######################################################################
Exit(){
    if [ "$#" -ne 3 ]; then
        echo -e "   Function Exit() error! Usage: Exit <FILE> <FUNC> <ERRORCODE>\n"
        exit 250
    fi
    
    if [ -n "`echo $3 | tr -d '[0-9]'`" ]; then 
        echo -e "   Function Exit() error! <ERRORCODE> must be number\n"
        exit 250
    fi
    
    scriptfile=$1
    funcname=$2
    errorcode=$3
    
    ## 防止某些意外退出导致不能使用回退键删除
    /bin/stty "$OLD_STTY_SETTING"
    tput sgr0
    /bin/stty erase '^?'
    echo "${CURSORON}"
    /bin/stty echo    
    echo
    
    # 根据退出码从${LIB_DIR}/errorcode中拿中英文的错误描述
    logfile=$(File_Converter log $scriptfile)
    error_obj=$(grep -v " *#" "${LIB_DIR}/errorcode" | grep -v "^$"| grep -wA2 "ErrorCode=$errorcode")
 
    
    # 中英文的不同显示
    if [ "$LANGUAGE" = "cn" ]; then
        cat <<EOF

    出错代码：$errorcode
    出错章节：$scriptfile
    错误函数：$funcname
    错误描述：`echo -e "$error_obj" | grep "MSG-CN" | awk -F'=' '{print $2}'`
    更详细错误，见日志: ${UNDERLINE}tail -50 $logfile${NORMAL}
EOF
    else
        cat <<EOF

    Error Code：$errorcodGe
    Error Chapter: $scriptfile
    Error Function: $funcname
    Error Description：`echo -e "$error_obj" | grep "MSG-EN" | awk -F'=' '{print $2}'`
    Get more detail log: ${UNDERLINE}tail -50 $logfile${NORMAL}
EOF

    fi
    
    
    # Alway log english to logfile
    cat <<EOF >> "$logfile"

    Error Date: `$NOW_TIME`
    Error Code：$errorcode
    Error Chapter: $scriptfile
    Error Function: $funcname
    Error Description：`echo -e "$error_obj" | grep "MSG-EN" | awk -F'=' '{print $2}'`

EOF

    exit $errorcode

}


# 作用: 函数return时,从errorCode库中拿详细返回信息,并将信息记入debug日志
# 使用方法：$RETURN <RETURNCODE>
# 注意：从returncode中拿
######################################################################
RETURN="Return $0 ${FUNCNAME:-MAIN}"
Return(){
    if [ "$#" -ne 3 ]; then
        echo -e "   Function Exit() error! Usage: Exit <FILE> <FUNC> <RETURNCODE>\n"
        exit 250
    fi
    
    if [ -n "`echo $3 | tr -d '[0-9]'`" ]; then 
        echo -e "   Function Exit() error! <RETURNCODE> must be number\n"
        exit 250
    fi
    
    scriptfile=$1
    funcname=$2
    returncode=$3
    
    # 根据退出码从${LIB_DIR}/returncode中拿中英文的描述
    logfile=$(File_Converter log $scriptfile)
    return_obj=$(grep -v " *#" "${LIB_DIR}/returncode" | grep -v "^$"| \
    sed -n "/FuncName=$funcname/,/FuncName/p" | sed -n '$!p' | grep -wA2 "ReturnCode=$returncode")
 
    return_content=`echo -e "$return_obj" | grep "MSG-EN" | awk -F'=' '{print $2}'`
    return_content=${return_content:1:$((${#return_content}-2))}

    # Alway debug english to logfile
    echo -e "`$NOW_TIME`\t$scriptfile:$funcname\tDEBUG\t$return_content" >>$logfile


    return $3

}






<<EOF
# get the all function content that need to be run
THIS_CHAPTER=server_prepare
THIS_CHAPTER_CONTENT=`INI_Parser ${CONF_DIR}/${LAUNCHER} $THIS_CHAPTER`


# loop the chapter
for i in `INI_Parser ${CONF_DIR}/${LAUNCHER}`; do
    # get the chapter content
    THIS_CHAPTER_CONTENT=`INI_Parser ${CONF_DIR}/${LAUNCHER} $i`
    THIS_CHAPTER_FUNC_CONTENT=$(echo "$THIS_CHAPTER_CONTENT" | egrep -v "TOTALTIME|OUTKEYS")
    THIS_CHAPTER_FUNC_CONTENT_NL=$(echo "$THIS_CHAPTER_FUNC_CONTENT" | nl)
    THIS_CHAPTER_FUNC_COUNT=$(echo "$THIS_CHAPTER_FUNC_CONTENT" | wc -l)
    THIS_CHAPTER_TIMEOUT=$(echo "$THIS_CHAPTER_CONTENT" | grep TOTALTIME | awk -F'=' '{print $2}')
    THIS_CHAPTER_OUTKEYS=$(echo "$THIS_CHAPTER_CONTENT" | grep OUTKEYS | awk -F'=' '{print $2}')
    
    # set timeout
    echo $i:
    
    
    echo "$THIS_CHAPTER_FUNC_CONTENT_NL" | while read lineno line; do
        this_func=`echo $line | awk -F'=' '{print $1}'`
        this_args=`echo $line | awk -F'=' '{print $2}' | awk -F'|' '{print $1}' | tr -d '"'`
        Log DEBUG "$lineno/$THIS_CHAPTER_FUNC_COUNT: $this_func $this_args"
        
    done
    
    
done
EOF




