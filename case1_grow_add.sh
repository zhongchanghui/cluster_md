#!/bin/bash
# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

get_disk

#############################################################
##grow-add

ssh node1 mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev2 --assume-clean
ssh node2 mdadm -A $md $dev0 $dev2
check all nosync
check all raid1
check all bitmap
check all state UU
check all dmesg
ssh node1 mdadm --grow $md --raid-devices=3 --add $dev1
sleep 0.3
ssh node1 grep recovery /proc/mdstat
if [ $? -eq '0' ]
then
        check node1 wait
else
        check node2 recovery
        check node2 wait
fi
check all state UUU
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
ssh node1 mdadm --grow $md --raid-devices=3 --add $dev3
ssh node1 sleep 0.3
ssh node1 grep recovery /proc/mdstat
if [ $? -eq '0' ]
then
        check node1 wait
else
        check node2 recovery
        check node2 wait
fi
check all state UUU
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
ssh node1 mdadm --grow $md --raid-devices=3
ssh node1 sleep 0.3
ssh node1 grep recovery /proc/mdstat
if [ $? -eq '0' ]
then
        check node1 wait
else
        check node2 recovery
        check node2 wait
fi
check all state UUU
check all dmesg
stop_md all $md

##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend
