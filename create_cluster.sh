#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
#   Author: Changhui Zhong <czhong@redhat.com>
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh
. libcluster.sh

function runtest(){

ssh_free_secret

	user=root
	passwd=redhat

for i in 1 2 3;do
	auto_ssh $passwd $user@node$i "yum -y install pacemaker corosync fence-agents-all fence-agents-virsh fence-virt pcs  dlm  gfs2-utils lvm2-lockd iscsi-initiator-utils httpd wget mdadm"
	auto_ssh $passwd $user@node$i "systemctl start pcsd"
	auto_ssh $passwd $user@node$i "systemctl enable pcsd"
	auto_ssh $passwd $user@node$i "systemctl status pcsd"

	for j in 1 2 3;do
		mac=$(virsh dumpxml node$j | grep "mac address" | cut -d "'" -f 2)
                ip=$(arp -a | grep $mac | cut -d ")" -f 1 | cut -d "(" -f 2)
		auto_ssh $passwd $user@node$i "echo '192.168.122.1 host' >> /etc/hosts"
		auto_ssh $passwd $user@node$i "echo '$ip node$j' >> /etc/hosts"
	done
	auto_ssh $passwd $user@node$i "echo cluster123 | passwd --stdin hacluster"
done

expect <<EOF
set timeout 10
spawn ssh node1
expect "password: "
send "redhat\n"
expect "]# "
send "pcs host auth node1 node2\n"
expect "Username: "
send "hacluster\n"
expect "Passwoed: "
send "cluster123\n"
expect eof
EOF

auto_ssh $passwd $user@node1 "pcs cluster setup my_cluster --start node1 node2 --force"

auto_ssh $passwd $user@node1 "pcs cluster enable --all"

sleep 20

for i in 1 2;do
	auto_ssh $passwd $user@node$i "pcs status"
done
##create fence_xvm
#for i in 1 2;do
#        auto_ssh $passwd $user@node1 "pcs stonith create fence_vm$i fence_xvm port="node$i" pcmk_host_list="node$i""
#done
auto_ssh $passwd $user@node1 "pcs property set stonith-enabled=true"
auto_ssh $passwd $user@node1 "pcs resource create dlm --group locking ocf:pacemaker:controld op monitor interval=30s on-fail=fence"
auto_ssh $passwd $user@node1 "pcs resource clone locking interleave=true"
auto_ssh $passwd $user@node1 "pcs resource create lvmlockd --group locking ocf:heartbeat:lvmlockd op monitor interval=30s on-fail=fence"
auto_ssh $passwd $user@node1 "pcs stonith create fence_all fence_xvm key_file="/etc/cluster/fence_xvm.key" pcmk_reboot_action="reboot" pcmk_host_map="node1:node1,node2:node2" pcmk_host_list="node1,node2" pcmk_host_check="static-list""
auto_ssh $passwd $user@node1 "pcs property set stonith-enabled=true"
:<<!
expect <<EOF
set timeout 10
spawn ssh node1
expect "password: "
send "redhat\n"
expect "]# "
send "mdadm --create /dev/md0 --bitmap=clustered --raid-devices=2 --level=mirror --assume-clean /dev/sda /dev/sdc\n"
expect "Continue creating array? "
send "y\n"
expect eof
EOF
!
for i in 1 2;do
	auto_ssh $passwd $user@node$i "crm_verify -L -V"
        auto_ssh $passwd $user@node$i "pcs status --full"
	auto_ssh $passwd $user@node$i "ps -ef | grep lvmlockd"
#	auto_ssh $passwd $user@node$i "mdadm -A /dev/md0 /dev/sda /dev/sdc"
done

for i in 1 2;do
        auto_ssh $passwd $user@node$i "firewall-cmd --permanent --add-port=1229/tcp"
	auto_ssh $passwd $user@node$i "firewall-cmd --reload"
	auto_ssh $passwd $user@node$i "lsblk"


done


}



tlog "running $0"
trun "uname -a"
runtest

tend

