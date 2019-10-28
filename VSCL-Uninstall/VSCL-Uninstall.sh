#!/bin/bash
#
#=============================================================================
# NAME:		UNINSTALL-VSCL.SH
# Purpose:	Uninstall the McAfee VirusScan Command Line Scanner v6.1.0
#			from SaaS Linux PPM App servers
# Creator:	Nick Taylor, Sr. Engineer, CA SaaS Ops
# Date:		21-OCT-2019
# Version:	1.2
# PreReqs:	Linux
#			CA PPM Application Server
#			VSCL antivirus scanner installed
#			unzip, tar, gunzip, yes, gclib > 2.7 utilities in OS
# Params:   none
# Switches: none
# Imports:  none
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================
UVSCAN_HOME=/usr/local/uvscan/
TEMP_DIR=./VSCL-TEMP/
CLAMAV_HOME=/fs0/od/clamav/bin/
CLAMSCAN_EXE=$CLAMAV_HOME/clamscan
CLAMSCAN_BACKUP=$CLAMSCAN_EXE.orig
INSTALLER_ZIP=./vscl-*.tar.gz
DAT_ZIP=./avvdat-*.zip
INSTALL_CMD=./install-uvscan
DAT_UPDATE_CMD=./update-uvscan-dat.sh

#=============================================================================
# FUNCTIONS
#=============================================================================

function do_exit {
	echo ===========================
	echo $(date +'%x %X')
	echo Ending with exit code: $1

	exit $1
}

#=============================================================================
# MAIN
#=============================================================================
echo Beginning VSCL uninstallation
echo $(date +'%x %X')
echo =============================

# uninstall the uvscan product and remove the uninstaller
if [ -d $UVSCAN_HOME ]
then
	echo Running uvscan uninstaller...
	yes | $UVSCAN_HOME/uninstall-uvscan $UVSCAN_HOME
	rm -rf $UVSCAN_HOME
else
	echo ERROR: uvscan product not found!
	do_exit 1
fi

if [ -f $CLAMSCAN_BACKUP ]
then
	# clamscan was replaced previously
	# delete the impersonator file or symlink created for uvwrap
	echo ClamAV scanner backup detected, restoring...
	rm -f $CLAMSCAN_EXE

	# copy original clamscan file back
	mv $CLAMSCAN_BACKUP $CLAMSCAN_EXE
	chmod +x $CLAMSCAN_EXE
else
	echo ClamAV scanner backup NOT detected, skipping...
fi

do_exit 0
