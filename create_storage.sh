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
	user=root
	passwd=redhat

for i in 1 2;do
	auto_ssh $passwd $user@storage$i "yum -y install targetcli fence-virt*"
	auto_ssh $passwd $user@storage$i "systemctl start target"
	auto_ssh $passwd $user@storage$i "systemctl enable target"
	auto_ssh $passwd $user@storage$i "systemctl status target"
    auto_ssh $passwd $user@storage$i "echo '192.168.122.1 host' >> /etc/hosts"

	for j in 1 2;do
		mac=$(virsh dumpxml storage$j | grep "mac address" | cut -d "'" -f 2)
                ip=$(arp -a | grep $mac | cut -d ")" -f 1 | cut -d "(" -f 2)
		auto_ssh $passwd $user@storage$i "echo '$ip storage$j' >> /etc/hosts"
	done
for k in 1 2 3;do
        auto_ssh $passwd $user@node$k "cat /etc/iscsi/initiatorname.iscsi | cut -d "=" -f 2" > iscsinode$k
        case $k in
                1)
                        iscsi1=$(cat iscsinode$k | grep iqn)
                        ;;
                2)
                        iscsi2=$(cat iscsinode$k | grep iqn)
                        ;;
                3)
                        iscsi3=$(cat iscsinode$k | grep iqn)
                        ;;
        esac
done

expect <<EOF
set timeout 10
spawn ssh storage$i
expect "password: "
send "redhat\n"
expect "]# "
send "targetcli\n"
expect "/> "
send "cd backstores/block\n"
expect "block> "
send "create name=disk1 dev=/dev/vdb\n"
expect "block> "
send "create name=disk2 dev=/dev/vdc\n"
send "cd /iscsi\n"
expect "iscsi> "
send "create iqn.2019-09.com.storage$i:target\n"
send "cd iqn.2019-09.com.storage$i:target/tpg1\n"
expect "tpg1> "
send "luns/ create /backstores/block/disk1\n"
send "luns/ create /backstores/block/disk2\n"
expect "tpg1> "
send "acls/ create $iscsi1\n"
send "acls/ create $iscsi2\n"
send "acls/ create $iscsi3\n"
expect "tpg1> "
send "cd /\n"
send "exit\n"
expect eof
EOF

auto_ssh $passwd $user@storage$i "firewall-cmd --permanent --add-port=3260/tcp"
auto_ssh $passwd $user@storage$i "firewall-cmd --reload"
for h in 1 2 3;do
auto_ssh $passwd $user@node$h "systemctl start iscsid"
auto_ssh $passwd $user@node$h "systemctl enable iscsid"
mac=$(virsh dumpxml storage$i | grep "mac address" | cut -d "'" -f 2)
ip=$(arp -a | grep $mac | cut -d ")" -f 1 | cut -d "(" -f 2)
auto_ssh $passwd $user@node$h "echo '$ip storage$i' >> /etc/hosts"
auto_ssh $passwd $user@node$h "iscsiadm -m discovery -t st -p $ip"
auto_ssh $passwd $user@node$h "iscsiadm -m node -T iqn.2019-09.com.storage$i:target -p $ip -l"
auto_ssh $passwd $user@node$h "lsblk"
done
done
}



tlog "running $0"
trun "uname -a"
runtest

tend

