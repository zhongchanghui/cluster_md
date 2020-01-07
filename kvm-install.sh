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

function runtest (){
	tok "lsmod | grep kvm"
	if [ $? -ne 0 ];then
		exit && echo 'KVM mode is not loaded!'
	fi
	grep -E "(vmx|svm)" /proc/cpuinfo &>/dev/null
	if [ $? -ne 0 ];then
		exit && echo 'You computer is not SUPPORT Virtual Tech OR the VT is NOT OPEN!'
	fi

	systemctl start libvirtd
	systemctl enable libvirtd
	mkdir -p /home/image
	mkdir -p /home/os
	rm -rf ~/.ssh/*
	sed -i '/192/d' /etc/hosts

    mkdir /etc/cluster
    dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=4k count=1
    fence-virtd_conf
    systemctl enable fence_virtd
    systemctl start fence_virtd
    firewall-cmd --permanent --add-port=1229/udp
    firewall-cmd --reload

	user=root
	passwd=redhat

	for i in 1 2 3 4;do
		tok "qemu-img create -f qcow2 /home/image/disk$i.qcow2 10G"
	done

	for i in 1 2 3;do
		tok "qemu-img create -f qcow2 /home/image/node$i.qcow2 20G"
		sed -i "s/^network  --hostname=.*/network  --hostname=node$i/" ks.cfg
		tok "create_node"
		wait
		tok "virsh list --all"
		status=$(virsh list --all | grep node$i |  awk '{print $3}')
		echo $status			
		while [ $status != "shut" ]; do
                        sleep 60
			echo $status
			status=$(virsh list --all | grep node$i |  awk '{print $3}')
		done
		tok "virsh start node$i"
		sleep 20
		tok "check_node_login"
		while [ $? -ne 0 ];do
			tok "check_node_login"
		done

		tok "login_node"
		tok "virsh list --all"

		mac=$(virsh dumpxml node$i | grep "mac address" | cut -d "'" -f 2)
		ip=$(arp -a | grep $mac | cut -d ")" -f 1 | cut -d "(" -f 2)
		echo "$ip node$i" >> /etc/hosts

		auto_ssh $passwd $user@node$i "lsblk"
		file=/etc/yum.repos.d/
		auto_scp $passwd $file $user@node$i:/etc/
		auto_ssh $passwd $user@node$i "yum -y install pacemaker corosync fence-agents-all fence-agents-virsh fence-virt* pcs  dlm  gfs2-utils  iscsi-initiator-utils httpd wget"
		auto_ssh $passwd $user@node$i "yum groupinstall 'High Availability' -y"
		auto_ssh $passwd $user@node$i "yum groupinstall 'Resilient Storage' -y"
		auto_ssh $passwd $user@node$i " firewall-cmd --permanent --add-service=high-availability"
		auto_ssh $passwd $user@node$i " firewall-cmd --reload "
		auto_ssh $passwd $user@node$i "mkdir -p /etc/cluster"
		file=/etc/cluster/fence_xvm.key
		auto_scp $passwd $file $user@node$i:/etc/cluster/
		auto_ssh $passwd $user@node$i " firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.122.1" port port="1229" protocol="tcp" accept' "
		auto_ssh $passwd $user@node$i " firewall-cmd --reload "
		auto_ssh $passwd $user@node$i " fence_xvm -o list "

		file=/home/os/kernel136/
                auto_scp $passwd $file $user@node$i:/home/os/
		auto_ssh $passwd $user@node$i "rpm -Uvh /home/os/kernel*.rpm"
		auto_ssh $passwd $user@node$i "grub2-set-default 0"
		auto_ssh $passwd $user@node$i "grub2-mkconfig -o /boot/grub2/grub.cfg"
		auto_ssh $passwd $user@node$i "reboot"


	done

	for i in 1 2;do
		tok "qemu-img create -f qcow2 /home/image/storage$i.qcow2 30G"
		sed -i "s/^network  --hostname=.*/network  --hostname=storage$i/" ks.cfg
		tok "create_storage"
                wait
                tok "virsh list --all"
                status=$(virsh list --all | grep storage$i |  awk '{print $3}')
                echo $status                    
                while [ $status != "shut" ]; do
                        sleep 60
                        echo $status
                        status=$(virsh list --all | grep storage$i |  awk '{print $3}')
                done
                tok "virsh start storage$i"
                sleep 20
                tok "check_storage_login"
                while [ $? -ne 0 ];do
                        tok "check_storage_login"
                done

                tok "login_storage"
                tok "virsh list --all"

                mac=$(virsh dumpxml storage$i | grep "mac address" | cut -d "'" -f 2)
                ip=$(arp -a | grep $mac | cut -d ")" -f 1 | cut -d "(" -f 2)
                echo "$ip storage$i" >> /etc/hosts

                auto_ssh $passwd $user@storage$i "lsblk"
                file=/etc/yum.repos.d/
                auto_scp $passwd $file $user@storage$i:/etc/

	done
}

tlog "running $0"
trun "yum install -y fence-virt fence-virtd fence-virtd-multicast fence-virtd-libvirt qemu-kvm qemu-img libvirt* virt-manager virt-install libvirt-client"
trun "uname -a"
runtest

tend
