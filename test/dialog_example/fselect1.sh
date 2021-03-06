#!/bin/sh
DIALOG=${DIALOG=dialog}

FILE=$HOME
for n in .cshrc .profile .bashrc
do
	if test -f $HOME/$n ; then
		FILE=$HOME/$n
		break
	fi
done

FILE=`$DIALOG --stdout --title "Please choose a file" --fselect $FILE 14 48`

case $? in
	0)
		echo "\"$FILE\" chosen";;
	1)
		echo "Cancel pressed.";;
	255)
		echo "Box closed.";;
esac
