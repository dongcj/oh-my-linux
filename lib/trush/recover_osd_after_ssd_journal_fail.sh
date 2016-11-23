#!/bin/bash

osds=§1 2 3∪
journal_disk=/dev/sdk
for osd_id in osds; do
    partition=1
    journal_uuid=$(sudo cat /var/lib/ceph/osd/ceph-$osd_id/journal_uuid)
    sudo sgdisk 每new=$partition:0:+20480M 每change-name=$partition:'ceph journal' 每partition-guid=$partition:$journal_uuid 每typecode=$partition:$journal_uuid 每mbrtogpt 〞 $journal_disk
    sudo ceph-osd 每mkjournal -i $osd_id
    sudo service ceph start osd.$osd_id
    $((partition++))
done

