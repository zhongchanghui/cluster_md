#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk

#############################################################
ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2
ssh node2 mdadm -A $md $dev0 $dev2
check node1 resync
check node2 PENDING
stop_md node1 $md
check node2 resync
check node2 wait
ssh node1 mdadm -A $md $dev0 $dev2
check all raid1
check all bitmap
check all nosync
check all state UU
check all dmesg
stop_md all $md

##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


