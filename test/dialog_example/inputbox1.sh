#!/bin/sh
DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --cr-wrap \
	--title "INPUT BOX" --clear \
        --inputbox \
"Hi, this is an input dialog box. You can use
this to ask questions that require the user
to input a string as the answer. You can 
input strings of length longer than the 
width of the input box, in that case, the 
input field will be automatically scrolled. 
You can use BACKSPACE to correct errors. 

Try entering your name below:" 0 0 2> $tempfile

retval=$?

case $retval in
  0)
    echo "Input string is `cat $tempfile`";;
  1)
    echo "Cancel pressed.";;
  255)
    if test -s $tempfile ; then
      cat $tempfile
    else
      echo "ESC pressed."
    fi
    ;;
esac
