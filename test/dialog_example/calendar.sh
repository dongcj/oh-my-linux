#!/bin/sh
: ${DIALOG=dialog}

USERDATE=`$DIALOG --stdout --title "CALENDAR" --calendar "Please choose a date..." 0 0 7 7 1981`

case $? in
  0)
    echo "Date entered: $USERDATE.";;
  1)
    echo "Cancel pressed.";;
  255)
    echo "Box closed.";;
esac
