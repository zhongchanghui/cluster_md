#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk
#############################################################
##create md raid1

ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2
ssh node2 mdadm -A $md $dev0 $dev2
ssh node1 cat /proc/mdstat
ssh node2 cat /proc/mdstat
check node1 resync
check node2 raid1
check all wait
check all raid1
check all bitmap
check all nosync
check all state UU
check all dmesg
stop_md all $md

ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev0 $dev2
check all nosync
check all raid1
check all bitmap
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
stop_md all $md

name=tstmd
ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2 --name=$name --assume-clean
ssh node2 mdadm -A $md $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all state UU
for ip in node1 node2
do
        ssh $ip "mdadm -D $md | grep 'Name' | grep -q $name"
        [ $? -ne '0' ] &&
                die "$ip: check --name=$name failed."
done
check all dmesg
stop_md all $md
##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


