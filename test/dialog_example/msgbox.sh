#!/bin/sh
DIALOG=${DIALOG=dialog}

$DIALOG --title "MESSAGE BOX" --clear \
        --msgbox "Hi, this is a simple message box. You can use this to \
                  display any message you like. The box will remain until \
                  you press the ENTER key." 18 45

case $? in
  0)
    echo "OK";;
  255)
    echo "ESC pressed.";;
esac
