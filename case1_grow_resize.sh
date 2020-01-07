#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk

#############################################################
size=10000

ssh node1 mdadm -CR $md -l1 -b clustered --size $size -n2 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all state UU

ssh node1 mdadm --grow $md --size max
check node1 resync
check node1 wait
check all state UU

ssh node1 mdadm --grow $md --size $size
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


