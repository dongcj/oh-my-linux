#!/bin/sh

function show_note () {
    [[ -e /tmp/notes.lock ]] && return
    touch /tmp/notes.lock
    yad --text-info --show-uri --geometry=400x200-0-0 --name="notes" --window-icon="text-editor" \
        --title=$"Notes" --button="gtk-save:0" --button="gtk-close:1" \
        --editable --filename=${XDG_CACHE_HOME:-$HOME/.cache}/notes > /tmp/.notes
    [[ $? -eq 0 ]] && mv /tmp/.notes ${XDG_CACHE_HOME:-$HOME/.cache}/notes
    rm -f /tmp/notes.lock
}
export -f show_note

mkdir -p ${XDG_CACHE_HOME:-$HOME/.cache}
touch ${XDG_CACHE_HOME:-$HOME/.cache}/notes


show_note
# exec yad --notification --text=$"Text notes" --image="text-editor" --command "sh -c show_note"