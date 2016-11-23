#!/bin/sh
yad --image=drive-harddisk --text="Disk\ usage" --buttons-layout=end \
     --multi-progress $(df -h $1 | tail -n +2 |\
     awk '{printf "--bar=\"<b>%s</b> (%s) [%s/%s]\" %s ", $6, $1, $3, $2, $5}')