#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk

#############################################################
ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all state UU
check all dmesg
ssh node1 mdadm --manage $md --add-spare $dev1
check all spares 1
check all state UU
check all dmesg
stop_md all $md

ssh node1 mdadm -CR $md -l1 -b clustered -n2 -x1 $dev1 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev1 $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all spares 1
check all state UU
check all dmesg
ssh node1 mdadm --manage $md --add-spare $dev3
check all spares 2
check all state UU
check all dmesg
stop_md all $md
##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


