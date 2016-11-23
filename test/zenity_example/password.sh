#!/bin/sh

ENTRY=`zenity --password --username`

case $? in
         0)
        echo "用户名： `echo $ENTRY | cut -d'|' -f1`"
        echo "密码： `echo $ENTRY | cut -d'|' -f2`"
        ;;
         1)
                echo "停止登陆。";;
        -1)
                echo "发生意外错误。";;
esac
