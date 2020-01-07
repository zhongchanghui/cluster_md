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

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=kernel

# The name of the package under test:
PACKAGE_NAME=storage

# The path of the test below the package:
RELATIVE_PATH=mdadm/cluster_md

# Version of the Test. Used with make tag.
export TESTVERSION=1.0

# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(RELATIVE_PATH)


# A phony target is one that is not really the name of a file.
# It is just a name for some commands to be executed when you
# make an explicit request. There are two reasons to use a
# phony target: to avoid a conflict with a file of the same
# name, and to improve performance.
.PHONY: all install download clean

# executables to be built should be added here, 
# they will be generated on the system under test.
BUILT_FILES=

# data files, .c files, scripts anything needed to either compile the test 
# and/or run it.
FILES=$(METADATA) runtest.sh Makefile PURPOSE case1_create_mdraid1.sh case1_grow_add.sh case1_grow_bitmap-switch.sh case1_grow_resize.sh case2_manage_add.sh case2_manage_add-spare.sh case2_manage_re-add.sh case3_switch_recovery.sh case3_switch_resync.sh case4_cluster_IO.sh create_cluster.sh create_storage.sh kvm-install.sh libcluster.sh ks.cfg tc.sh


run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ *.rpm $(BUILT_FILES)

# You may need to add other targets e.g. to build executables from source code
# Add them here:


# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
# Change to the test owner's name
	@echo "Owner:        Changhui Zhong <czhong@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"       >> $(METADATA)
	@echo "License:      GPLv2 or above" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"    >> $(METADATA)
	@echo "Description:  cluster function">> $(METADATA)
	@echo "TestTime:     12h" >> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
# add any other packages for which your test ought to run here
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
	@echo "RhtsRequires: kernel-kernel-storage-include" >> $(METADATA)
	@echo "RhtsRequires: kernel-kernel-storage-iscsi-include" >> $(METADATA)
	@echo "RhtsRequires: kernel-kernel-storage-mdadm-include" >> $(METADATA)
	@echo "Requires:	 iproute" >> $(METADATA)
	@echo "Requires:	 mdadm" >> $(METADATA)
	@echo "Requires:	 iscsi-initiator-utils" >> $(METADATA)
	@echo "Requires:	 scsi-target-utils" >> $(METADATA)
# add any other requirements for the script to run here

# You may need other fields here; see the documentation
	rhts-lint $(METADATA)
