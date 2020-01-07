#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk

#############################################################
ssh node1 mdadm -CR $md -l1 -b clustered -n2 -x1 $dev1 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev1 $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all spares 1
check all state UU
check all dmesg
ssh node1 mdadm --manage $md --fail $dev0
sleep 0.3
check node1 recovery
stop_md node1 $md
check node2 recovery
check node2 wait
check node2 state UU
check all dmesg
stop_md node2 $md
##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


