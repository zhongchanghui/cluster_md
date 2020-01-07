#!/bin/bash
#   Author: Changhui Zhong <czhong@redhat.com>
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){
get_disk
:<<!
ssh node1 "pcs status --full"
ssh node1 "pcs stonith delete fence_all"
ssh node1 "pcs resource delete dlm"
ssh node1 "pcs resource create VIP ocf:heartbeat:IPaddr2 ip=192.168.122.170 cidr_netmask=24 op monitor interval=30s"
ssh node1 "pcs stonith create fence_vm fence_xvm pcmk_reboot_action="reboot" port="node2:2,node1:1" pcmk_host_list="node2,node1""
ssh node1 "pcs resource create dlm ocf:pacemaker:controld op monitor interval=30s on-fail=restart"
ssh node1 "pcs resource clone dlm interleave=true"
ssh node1 "pcs resource create lvmlockd ocf:heartbeat:lvmlockd op monitor interval=30s on-fail=restart"
ssh node1 "pcs resource clone lvmlockd interleave=true"
ssh node1 "pcs constraint order start dlm-clone then lvmlockd-clone"
ssh node1 "pcs constraint colocation add lvmlockd-clone with dlm-clone"
get_disk
#ssh node1 "mdadm -CR /dev/md0 --bitmap=clustered --metadata=1.2 --raid-devices=2 --level=mirror /dev/sda /dev/sdb"
ssh node1 "mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev1"
ssh node2 "mdadm -A $md $dev0 $dev1"
check all wait
check all raid1
check all bitmap
check all state UU
ssh node1 "pvcreate $md"
ssh node1 "vgcreate --shared shared_vg1 $md"
ssh node2 "vgchange --lock-start shared_vg1"
ssh node1 "lvcreate --activate sy -l 100%free -n shared_lv1 shared_vg1"
ssh node1 "mkfs.gfs2 -j2 -p lock_dlm -t my_cluster:gfs2-demo1 /dev/shared_vg1/shared_lv1"
ssh node1 "pcs resource create sharedlv1 ocf:heartbeat:LVM-activate lvname=shared_lv1 vgname=shared_vg1 activation_mode=shared vg_access_mode=lvmlockd"
ssh node1 "pcs resource clone sharedlv1 interleave=true"
ssh node1 "pcs resource create sharedfs1 ocf:heartbeat:Filesystem device="/dev/shared_vg1/shared_lv1" directory="/mnt/gfs1" fstype="gfs2" options=noatime op monitor interval=10s on-fail=restart"
ssh node1 "pcs resource clone sharedfs1 interleave=true"
ssh node1 "pcs constraint order start lvmlockd-clone then sharedfs-clone"
ssh node1 "pcs constraint colocation add sharedfs1-clone with lvmlockd-clone"
ssh node1 "lsblk"
ssh node2 "lsblk"
ssh node1 "pcs status --full"
#########!!!!!!
#ssh node1 "pcs resource create VIP ocf:heartbeat:IPaddr2 ip=192.168.122.170 cidr_netmask=24 op monitor interval=30s"
ssh node1 "pcs stonith create fence_vm fence_xvm pcmk_reboot_action="reboot" port="node2:2,node1:1" pcmk_host_list="node2,node1""
ssh node1 "pcs property set stonith-enabled=true"
ssh node1 "pcs resource create dlm --group locking ocf:pacemaker:controld op monitor interval=30s on-fail=fence"
ssh node1 "pcs resource clone locking interleave=true"
ssh node1 "pcs resource create lvmlockd --group locking ocf:heartbeat:lvmlockd op monitor interval=30s on-fail=fence"
sleep 20
!
ssh node1 "mdadm -CR $md -l1 -b clustered -n2 $dev0 $dev1"
ssh node2 "mdadm -A $md $dev0 $dev1"
check all wait
check all raid1
check all bitmap
check all state UU
#ssh node1 "pvcreate $md"
ssh node1 "vgcreate --shared shared_vg1 $md"
ssh node1 "vgchange --lock-start shared_vg1"
ssh node2 "vgchange --lock-start shared_vg1"
ssh node1 "lvcreate -a sy -l 100%free -n shared_lv1 shared_vg1"
ssh node1 "lvchange -a sy /dev/shared_vg1/shared_lv1"
ssh node1 "mkfs.gfs2 -j2 -p lock_dlm -t my_cluster:gfs2-demo1 /dev/shared_vg1/shared_lv1 <<EOF
y
EOF"
ssh node1 "pcs resource create sharedlv1 --group shared_vg1 ocf:heartbeat:LVM-activate lvname=shared_lv1 vgname=shared_vg1 activation_mode=shared vg_access_mode=lvmlockd"
ssh node1 "pcs resource clone shared_vg1 interleave=true"
ssh node1 "pcs constraint order start locking-clone then shared_vg1-clone"
ssh node1 "pcs resource create sharedfs1 --group shared_vg1 ocf:heartbeat:Filesystem device="/dev/shared_vg1/shared_lv1" directory="/mnt/gfs1" fstype="gfs2" options=noatime op monitor interval=10s on-fail=fence"
sleep 30
ssh node1 "pcs status --full"
check node1 wait
ssh node1 "lsblk"
ssh node2 "lsblk"
ssh node1 "dd if=/dev/urandom of=/mnt/gfs1/testfile1 bs=10M count=10"
echo $(ssh node1 md5sum /mnt/gfs1/testfile1 | awk '{print $1}') > md5sum11
echo $(ssh node2 md5sum /mnt/gfs1/testfile1 | awk '{print $1}') > md5sum12
diff md5sum11 md5sum12
if [ $? -ne 0 ];then
	printf "####data error####\n"
else
	printf "####data right####\n"
fi
ssh node2 "dd if=/dev/urandom of=/mnt/gfs1/testfile2 bs=10M count=10"
echo $(ssh node1 md5sum /mnt/gfs1/testfile2 | awk '{print $1}') > md5sum21
echo $(ssh node2 md5sum /mnt/gfs1/testfile2 | awk '{print $1}') > md5sum22
diff md5sum21 md5sum22
if [ $? -ne 0 ];then
	printf "####data error####\n"
else
        printf "####data right####\n"
fi

check all wait
check all raid1
check all bitmap
}

tlog "running $0"
trun "uname -a"
runtest

tend

