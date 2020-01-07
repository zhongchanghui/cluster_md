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
ssh node1 mdadm --manage $md --fail $dev0 --remove $dev0
ssh node1 mdadm --manage $md --re-add $dev0
check node1 recovery
check all wait
check all state UU
check all dmesg
stop_md all $md

##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


