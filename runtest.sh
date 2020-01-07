#!/bin/sh

# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Changhui Zhong <czhong@redhat.com>
# Include Beaker environment
. /usr/bin/rhts-environment.sh

sh kvm-install.sh
sh create_storage.sh
sh create_cluster.sh

for i in $(ls case*.sh);do

        echo "run the case $i"
        if [ -f $i ];then
                sleep 10;chmod +x $i
		rhts-run-simple-test cluster_md "sh $i"
                sleep 5
        fi
done
