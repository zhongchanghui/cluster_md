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

# switch 'clustered' bitmap to 'none', and then 'none' to 'internal'
stop_md node2 $md
ssh node1 mdadm --grow $md --bitmap=none
[ $? -eq '0' ] ||
        die "node1: change bitmap 'clustered' to 'none' failed."
ssh node1 mdadm -X $dev0 $dev2 &> /dev/null
[ $? -eq '0' ] &&
        die "node1: bitmap still exists in member_disks."
check all nobitmap
ssh node1 mdadm --grow $md --bitmap=internal
[ $? -eq '0' ] ||
        die "node1: change bitmap 'none' to 'internal' failed."
ssh node1 sleep 2
ssh node1 mdadm -X $dev0 $dev2 &> /dev/null
[ $? -eq '0' ] ||
        die "node1: create 'internal' bitmap failed."
check node1 bitmap

# switch 'internal' bitmap to 'none', and then 'none' to 'clustered'
ssh node1 mdadm --grow $md --bitmap=none
[ $? -eq '0' ] ||
        die "node1: change bitmap 'internal' to 'none' failed."
ssh node1 mdadm -X $dev0 $dev2 &> /dev/null
[ $? -eq '0' ] &&
        die "node1: bitmap still exists in member_disks."
check node1 nobitmap
ssh node1 mdadm --grow $md --bitmap=clustered
[ $? -eq '0' ] ||
        die "node1: change bitmap 'none' to 'clustered' failed."
ssh node2 mdadm -A $md $dev0 $dev2
ssh node1 sleep 2
for ip in node1 node2
do
      ssh $ip "mdadm -X $dev0 $dev2 | grep -q 'Cluster name'" ||
                die "$ip: create 'clustered' bitmap failed."
done
check all bitmap
check all state UU
check all dmesg
stop_md all $md
##########################################################################
}

tlog "running $0"
trun "uname -a"
runtest

tend


