#!/bin/sh
DIALOG=${DIALOG=dialog}

FILE=`$DIALOG --stdout --title "Please choose a file" --fselect $HOME/ 0 0`

case $? in
	0)
		echo "\"$FILE\" chosen";;
	1)
		echo "Cancel pressed.";;
	255)
		echo "Box closed.";;
esac
