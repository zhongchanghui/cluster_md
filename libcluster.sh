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
source tc.sh || exit 1


######create node
function create_node (){

virt-install -d --virt-type=kvm --name=node$i  --vcpus=1 --memory=4096 --location=/home/os/RHEL-8.1.0-20190806.2-x86_64-dvd1.iso --disk path=/home/image/node$i.qcow2 --initrd-inject=ks.cfg --network bridge=virbr0 --graphics none --noautoconsole --extra-args='ks=file:/ks.cfg console=ttyS0' --force

}


######create storage
function create_storage (){
if [ $i == 1 ];then
        virt-install -d --virt-type=kvm --name=storage1 --vcpus=1 --memory=4096 --location=/home/os/RHEL-8.1.0-20190806.2-x86_64-dvd1.iso --disk path=/home/image/storage1.qcow2 --disk path=/home/image/disk1.qcow2 --disk path=/home/image/disk2.qcow2 --initrd-inject=ks.cfg --network bridge=virbr0 --graphics none --noautoconsole --extra-args='ks=file:/ks.cfg console=ttyS0' --force
else
        virt-install -d --virt-type=kvm --name=storage2 --vcpus=1 --memory=4096 --location=/home/os/RHEL-8.1.0-20190806.2-x86_64-dvd1.iso --disk path=/home/image/storage2.qcow2 --disk path=/home/image/disk3.qcow2 --disk path=/home/image/disk4.qcow2 --initrd-inject=ks.cfg --network bridge=virbr0 --graphics none --noautoconsole --extra-args='ks=file:/ks.cfg console=ttyS0' --force
fi
}

########################################################

function check_node_login (){
echo $(
expect <<EOF
set timeout 5
spawn virsh console node$i
expect {
"Escape character is ^]" { send "\n" }
{send "\n"}
{send "\n"}
}
expect eof
EOF
) | grep node
}

function check_storage_login (){
echo $(
expect <<EOF
set timeout 5
spawn virsh console storage$i
expect {
"Escape character is ^]" { send "\n" }
{send "\n"}
{send "\n"}
}
expect eof
EOF
) | grep storage

}
function login_node (){
expect <<-EOF
set timeout 5
spawn virsh console node$i
expect "Escape character is ^]"
send "\n"
expect "login: "
send "root\n"
expect "password: "
send "redhat\n"
expect "]# "
send "ip addr\n"
send "ip addr > ip.log\n"
send "uname -r\n"
send "lsblk\n"
send "ls\n"
expect eof
EOF
}

function login_storage (){
expect <<-EOF
set timeout 5
spawn virsh console storage$i
expect "Escape character is ^]"
send "\n"
expect "login: "
send "root\n"
expect "password: "
send "redhat\n"
expect "]# "
send "ip addr\n"
send "ip addr > ip.log\n"
send "uname -r\n"
send "lsblk\n"
send "ls\n"
expect eof
EOF

}

function auto_ssh (){
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
    return $?
}

auto_scp () {
        expect -c "set timeout -1;
                spawn scp -r -o StrictHostKeyChecking=no $2  ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 1;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
    return $?
}

function ssh_free_secret (){
expect <<EOF
set timeout 10
spawn ssh-keygen
expect "id_rsa): "
send "\r"
expect "passphrase): "
send "\r"
expect "again: "
send "\r"
expect eof
EOF

for i in 1 2 3;do
expect <<EOF
set timeout 10
spawn ssh -o StrictHostKeyChecking=no node$i
expect "password: "
send "redhat\n"
expect "]# "
send "ssh-keygen\n"
expect "id_rsa): "
send "\r"
expect "passphrase): "
send "\r"
expect "again: "
send "\r"
expect eof
EOF

expect <<EOF
set timeout 10
spawn ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@node$i
expect "password: "
send "redhat\n"
expect eof
EOF

expect <<EOF
set timeout 10
spawn ssh -o StrictHostKeyChecking=no node$i
expect "password: "
send "redhat\n"
expect "]# "
send "ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@host\n"
expect "password: "
send "redhat\n"
expect eof
EOF
done
}

function fence-virtd_conf (){
expect <<EOF
set timeout 10
spawn fence_virtd -c
expect "Module search path"
send "\r"
expect "Listener module"
send "\r"
expect "Multicast IP Address"
send "\r"
expect "Multicast IP Port"
send "\r"
expect "Interface"
send "\r"
expect "Key File"
send "\r"
expect "Backend module"
send "\r"
expect "Libvirt URI"
send "\r"
expect "Replace"
send "y\r"
expect eof
EOF
}

########################################################
get_disk () {

devlist=()
for i in 1 2;do
        devlist+=( $(ssh node1 "ls /dev/disk/by-path/*storage$i*"))
done
echo "devlist: ${devlist[@]}"
num=$(expr ${#devlist[*]} - 1 )
for i in $(seq 0 ${#devlist[@]});do
        eval "dev$i=${devlist[$i]}"
done
echo $dev0
echo $dev1
echo $dev2
echo $dev3
md=/dev/md0
}

#########################################################
# $1/node, $2/optional
NODE1=node1
NODE2=node2
stop_md()
{
	if [ "$1" == "all" ]
        then
                NODES=(node1 node2)
        elif [ "$1" == "node1" -o "$1" == "node2" ]
        then
		NODES=($1)
        else
                echo "$1: unknown parameter."
        fi
        if [ -z "$2" ]
        then
                for ip in ${NODES[@]}
                do
                        ssh $ip mdadm -Ssq
#			ssh $ip mdadm --stop --scan
                done
        else
                for ip in ${NODES[@]}
                do
                      ssh $ip mdadm -S $2
                done
 	fi
}

save_log()
{
        status=$1
        logfile=/home/testlog

        for ip in node1 node2
        do
                echo "##$ip: saving dmesg." >> $logfile
                ssh $ip "dmesg -c" >> $logfile
                echo "##$ip: saving proc mdstat." >> $logfile
                ssh $ip "cat /proc/mdstat" >> $logfile
                array=($(ssh $ip "mdadm -Ds | cut -d' ' -f2"))

                if [ ! -z "$array" -a ${#array[@]} -ge 1 ]
                then
                        echo "##$ip: mdadm -D ${array[@]}" >> $logfile
                        ssh $ip "mdadm -D ${array[@]}" >> $logfile
                        md_disks=($(ssh $ip "mdadm -DY ${array[@]} | grep "/dev/" | cut -d'=' -f2"))
                        cat /proc/mdstat | grep -q "bitmap"
                        if [ $? -eq 0 ]
                        then
                                echo "##$ip: mdadm -X ${md_disks[@]}" >> $logfile
                                ssh $ip "mdadm -X ${md_disks[@]}" >> $logfile
                                echo "##$ip: mdadm -E ${md_disks[@]}" >> $logfile
                                ssh $ip "mdadm -E ${md_disks[@]}" >> $logfile
                        fi
                else
                        echo "##$ip: no array assembled!" >> $logfile
                fi
        done
        [ "$1" == "fail" ] &&
                echo "See $logfile for details"
        stop_md all
}

do_clean()
{
        tok mdadm --zero-superblock /dev/sd[a-d] &> /dev/null
}

# check: $1/cluster_node $2/feature $3/optional
check()
{
        NODES=()
        if [ "$1" == "all" ]
        then
                NODES=(node1 node2)
        elif [ "$1" == "node1" -o "$1" == "node2" ]
        then
                NODES=$1
        else
                die "$1: unknown parameter."
        fi
        case $2 in
                spares )
                        for ip in ${NODES[@]}
                        do
                                spares=$(ssh $ip "tr '] ' '\012\012' < /proc/mdstat | grep -c '(S)'")
                                [ "$spares" -ne "$3" ] &&
                                        die "$ip: expected $3 spares, but found $spares"
                        done
                ;;
                raid* )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -sq "$2" /proc/mdstat" ||
                                        die "$ip: check '$2' failed."
                        done
                ;;
                PENDING | recovery | resync | reshape )
                        cnt=5
                        for ip in ${NODES[@]}
                        do
                                while ! ssh $ip "grep -sq '$2' /proc/mdstat"
                                do
                                        if [ "$cnt" -gt '0' ]
                                        then
                                                sleep 0.2
                                                cnt=$[cnt-1]
                                        else
                                                die "$ip: no '$2' happening!"
                                        fi
                                done
                        done

                ;;
                wait )
                        local cnt=60
                        for ip in ${NODES[@]}
                        do
                                p=$(ssh $ip "cat /proc/sys/dev/raid/speed_limit_max")
                                ssh $ip "echo 200000 > /proc/sys/dev/raid/speed_limit_max"
                                while ssh $ip "grep -Esq '(resync|recovery|reshape|check|repair)' /proc/mdstat"
                                do
                                        if [ "$cnt" -gt '0' ]
                                        then
                                                sleep 5
                                                cnt=$[cnt-1]
                                        else
                                                die "$ip: Check '$2' timeout over 300 seconds."
                                        fi
                                done
                                ssh $ip "echo $p > /proc/sys/dev/raid/speed_limit_max"
                        done
                ;;
                bitmap )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -sq '$2' /proc/mdstat" ||
                                        die "$ip: no '$2' found in /proc/mdstat."
                        done
                ;;
                nobitmap )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -sq 'bitmap' /proc/mdstat" &&
                                        die "$ip: 'bitmap' found in /proc/mdstat."
                        done
                ;;
                chunk )
                        for ip in ${NODES[@]}
                        do
                                chunk_size=`awk -F',' '/chunk/{print $2}' /proc/mdstat | awk -F'[a-z]' '{print $1}'`
                                [ "$chunk_size" -ne "$3" ] &&
                                        die "$ip: chunksize should be $3, but it's $chunk_size"
                        done
                ;;
                state )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -Esq 'blocks.*\[$3\]\$' /proc/mdstat" ||
                                        die "$ip: no '$3' found in /proc/mdstat."
                        done
                ;;
                nosync )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -Eq '(resync|recovery)' /proc/mdstat" &&
                                        die "$ip: resync or recovery is happening!"
                        done
                ;;
                readonly )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "grep -sq "read-only" /proc/mdstat" ||
                                        die "$ip: check '$2' failed!"
                        done
                ;;
                dmesg )
                        for ip in ${NODES[@]}
                        do
                                ssh $ip "dmesg | grep -iq 'error\|call trace\|segfault'" &&
                                        die "$ip: check '$2' prints errors!"
                        done
                ;;
                * )
                        die "unknown parameter $2"
                ;;
        esac
}
################################################################

die()
{
    local message=$1
    [ -z "$message" ] && message="Died"
    echo "$message at ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}." >&2
    echo -e "\n\tERROR: $* \n"
    date >> test.log
    echo "$message at ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}." >> test.log
    stop_md all $md
    exit 1
}
:<<!
die() {
        echo -e "\n\tERROR: $* \n"
        save_log fail
        exit 2
}
!

