#!/bin/bash

osds=��1 2 3��
journal_disk=/dev/sdk
for osd_id in osds; do
    partition=1
    journal_uuid=$(sudo cat /var/lib/ceph/osd/ceph-$osd_id/journal_uuid)
    sudo sgdisk �Cnew=$partition:0:+20480M �Cchange-name=$partition:'ceph journal' �Cpartition-guid=$partition:$journal_uuid �Ctypecode=$partition:$journal_uuid �Cmbrtogpt �� $journal_disk
    sudo ceph-osd �Cmkjournal -i $osd_id
    sudo service ceph start osd.$osd_id
    $((partition++))
done

