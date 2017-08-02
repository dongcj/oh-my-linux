#!/bin/bash

osds=1 2 3
journal_disk=/dev/sdk
for osd_id in osds; do
    partition=1
    journal_uuid=$(sudo cat /var/lib/ceph/osd/ceph-$osd_id/journal_uuid)
    sudo sgdisk new=$partition:0:+20480M  change-name=$partition:'ceph journal' partition-guid=$partition:$journal_uuid typecode=$partition:$journal_uuid mbrtogpt $journal_disk
    sudo ceph-osd mkjournal -i $osd_id
    sudo service ceph start osd.$osd_id
    $((partition++))
done

