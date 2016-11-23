#! /bin/sh
: ${DIALOG=dialog}
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_ESC=255}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --backtitle "Red Hat Software Linux" \
	--title "CHECKLIST BOX" \
        --checklist "Hi, this is a checklist box. You can use this to \n\
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
        "Cat"    "No, never put a dog and a cat together!" oN \
        "Fish"   "Cats like fish." On \
        "Lemon"  "You know how it tastes." on 2> $tempfile

retval=$?

choice=`cat $tempfile`
case $retval in
  $DIALOG_OK)
    echo "'$choice' chosen.";;
  $DIALOG_CANCEL)
    echo "Cancel pressed.";;
  $DIALOG_ESC)
    echo "ESC pressed.";;
  *)
    echo "Unexpected return code: $retval (ok would be $DIALOG_OK)";;
esac
