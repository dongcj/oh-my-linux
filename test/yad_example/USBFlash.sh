#!/bin/sh

#This example demonstrate how to use yad --notification. There is two part of example 
# - first one is a set of udev rules for automounting usb flash drives, 
# and second one - script which watches for creating or deleting new mount points and show 
# notification icon with menu for unmounting flash drives

BASEDIR=/mnt/usb
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)

function on_exit () {
    echo "quit" >&3
    rm -f $PIPE
}

function on_unmount () {
    gsu umount $1
    ret=$?
    if [[ $ret -eq 0 ]]; then
    notify-send -u normal -i drive-removable-media -t 900 \
        "${1##*/}" "${1##*/} unmounted successfully"
    else
    notify-send -u critical -i drive-removable-media -t 1200 \
        "${1##*/}" "Unmount ${1##*/} failed (error code $ret)!!!"
    fi
}

function update_state () {
    MENU=
    for d in $(find $BASEDIR -mindepth 1 -maxdepth 1 -type d); do
    MENU="${d##*/}!sh -c 'on_unmount $d'|$MENU" 
    done
    if [[ -z $MENU ]]; then
    echo "visible:false" >&3
    else
    echo "visible:true" >&3
    echo "menu:$MENU" >&3
    fi
}

mkfifo $PIPE
exec 3<> $PIPE

export -f on_unmount
trap on_exit EXIT

yad --notification --kill-parent --listen \
    --image=drive-removable-media --text="Removable media" \
    --command="xdg-open $BASEDIR" <&3 &

update_state

inotifywait -m -e create -e delete $BASEDIR 2> /dev/null | while read LINE; do
    case $(echo $LINE | awk '{print $2}') in
    "CREATE,ISDIR") update_state ;;
    "DELETE,ISDIR") update_state ;;
    esac
done