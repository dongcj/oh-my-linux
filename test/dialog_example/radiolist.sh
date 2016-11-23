#! /bin/sh
DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --backtitle "Red Hat Software Linux" \
	--title "RADIOLIST BOX" --clear \
        --radiolist "Hi, this is a radiolist box. You can use this to \n\
present a list of choices which can be turned on or \n\
off. If there are more items than can fit on the \n\
screen, the list will be scrolled. You can use the \n\
UP/DOWN arrow keys, the first letter of the choice as a \n\
hot key, or the number keys 1-9 to choose an option. \n\
Press SPACE to toggle an option on/off. \n\n\
  Which of the following are fruits?" 20 61 5 \
        "Apple"  "It's an apple." off \
        "Dog"    "No, that's not my dog." ON \
        "Orange" "Yeah, that's juicy." off \
        "Chicken"    "Normally not a pet." off \
        "Cat"    "No, never put a dog and a cat together!" off \
        "Fish"   "Cats like fish." off \
        "Lemon"  "You know how it tastes." off 2> $tempfile

retval=$?

choice=`cat $tempfile`
case $retval in
  0)
    echo "'$choice' chosen.";;
  1)
    echo "Cancel pressed.";;
  255)
    echo "ESC pressed.";;
esac
