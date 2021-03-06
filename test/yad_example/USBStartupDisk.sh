#!/bin/sh

#!/bin/bash

#Copy to USB Key Tool Copyright 2009,2011 by Tony Brijeski under the GPL V2
#Using yad for gui calls

DIALOG="`which yad`"
TITLE="--always-print-result --dialog-sep --image=/usr/share/icons/remastersys.png --title="
TITLETEXT="Remastersys USB Startup Disk Tool"
TEXT="--text="
ENTRY="--entry "
ENTRYTEXT="--entry-text "
FILESELECTION="--file-selection "
MENU="--list --column=Pick --column=Info"
PASSWORD="--entry --hide-text "

testroot="`whoami`"

if [ "$testroot" != "root" ]; then
    remsu $0 &
    exit
fi

copymenu () {
    if [ "$1" = "(null)" ]; then
    $DIALOG $TITLE"$TITLETEXT" $TEXT"\n\nYou must select a usb key to use. Click OK to return to main menu.\n"
    mainmenu
    fi
    if [ "$2" = "(null)" ]; then
    $DIALOG $TITLE"$TITLETEXT" $TEXT"\n\nYou must select a source to use. Click OK to return to main menu.\n"
    mainmenu
    fi

    $DIALOG $TITLE"$TITLETEXT" $TEXT"\n\nThis will completely replace the contents of your usb drive with the Bootable Live System.\n\n \
You will not be able to undo this operation once it starts.\n\nClick OK to continue?\n"

    if [ $? != 0 ]; then
    mainmenu
    fi

    umount `mount | grep $1 | awk '{print $1}'`

    progressbar "Copying to USB Key Now \n\nPlease Wait \n" &
#do the copy
    dd if=$2 of=/dev/$1 bs=1M
    sync
    killall -KILL tail

    $DIALOG $TITLE"$TITLETEXT" $TEXT"\n\nCopy to USB key completed. \nClick OK to return to main menu.\n"
    mainmenu
}

progressbar () {
    tail -f $0 | $DIALOG $TITLE"$TITLETEXT" $TEXT"$@" --progress --pulsate --auto-close
}

mainmenu () {
    DEVS=""
    DEVS=`ls -l /dev/disk/by-path/*usb* | grep -v "part" | awk '{print $NF}' | awk -F "/" '{print $NF}'`
    if [ "$DEVS" != "" ]; then
    for i in $DEVS; do
        USBDRIVESIZE=`grep -m 1 "$i" /proc/partitions | awk '{print $3}'`
        USBDRIVES="$USBDRIVES!$i-$USBDRIVESIZE"
    done
    else
    $DIALOG $TITLE"$TITLETEXT" $TEXT"\n\nNo USB Keys found.\n\n\nPlease insert a USB Key and then\nclick OK to return to main menu\nor Cancel to quit.\n"
    if [ "$?" = "0" ]; then
        mainmenu
    else
        exit
    fi
    fi

    CHOICES=`$DIALOG $TITLE"$TITLETEXT" --form --field="USB Key:CB" $USBDRIVES --field="Source Image:FL" --button="Quit:2" --button="Copy to USB Key:1"`
    retval="$?"

    if [ "$retval" = "1" ]; then
    USBDRIVE=`echo $CHOICES | cut -d "|" -f 1 | cut -d "-" -f 1`
    PICKSOURCE=`echo $CHOICES | cut -d "|" -f 2`
    copymenu $USBDRIVE $PICKSOURCE
    else
    exit
    fi
}

mainmenu