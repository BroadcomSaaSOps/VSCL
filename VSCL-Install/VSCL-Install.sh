#!/bin/bash


#=============================================================================
# NAME:		INSTALL-VCSL.SH
# Purpose:	Installer for McAfee VirusScan Command Line Scanner 6.1.0 on SaaS 
#			Linux PPM App servers
# Creator:	Nick Taylor, Sr. Engineer, CA SaaS Ops
# Date:		03-NOV-2017
# Version:	2.0
# PreReqs:	Linux
#			CA PPM Application Server
#			ClamAV antivirus scanner installed and integrated with PPM
#				default install directory: /fs0/od/clamav/bin
#			VSCL installer (vscl-*.tar.gz) in directory
#			Latest VSCL DAT .ZIP file (avvdat-*.zip) in directory
#				DAT update will warn if not present
#			update-uvscan-dat.sh in directory
#			uvwrap.sh in directory
#			unzip, tar, gunzip, gclib > 2.7 utilities in OS
#=============================================================================
# Params:	NONE
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
INSTALL_CMD=$TEMP_DIR/install-uvscan
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

echo Beginning VSCL installation
echo $(date +'%x %X')
echo ===========================

# make temp directory off installer directory
echo Creating temp directory...
if [ ! -d $TEMP_DIR ]; then mkdir -p $TEMP_DIR; fi

# move install files to unzip into temp
if [ -f $INSTALLER_ZIP ]; then
	echo Copying install archive to temp directory...
	cp $INSTALLER_ZIP $TEMP_DIR
else 
	echo ERROR: Installer archive \'$INSTALLER_ZIP\' does not exist!
	do_exit 1
fi

# untar installer archive in-place and install uvscan with default settings
echo Installing VSCL...
cd $TEMP_DIR
tar -xzf $INSTALLER_ZIP
$INSTALL_CMD -y

# remove temp directory
echo Removing temp directory...
cd ..
rm -rf $TEMP_DIR

# Run shell file to update the scanner with the latest AV definitions
if [ -f $DAT_ZIP ]
then
	echo Unpacking DAT files to uvscan directory...
	$DAT_UPDATE_CMD $DAT_ZIP
else
	echo WARNING: DAT files unavailable for installation!
fi

# make uvwrap.sh executable and copy to uvscan directory
echo Setting up shim wrapper for uvscan...
chmod +x ./uvwrap.sh
if [ -f $UVSCAN_HOME/uvwrap.sh ]; then rm -f $UVSCAN_HOME/uvwrap.sh; fi
cp ./uvwrap.sh $UVSCAN_HOME

if [ ! -d $CLAMAV_HOME ]; then
	echo WARNING: ClamAV home directory \'$CLAMAV_HOME\' does not exist.  Creating...
	mkdir -p $CLAMAV_HOME
fi

if [ -f $CLAMSCAN_BACKUP ]
then
	# save file exists, bypass save
	echo WARNING: Original ClamAV scanner executable already saved to \'$CLAMSCAN_BACKUP\'.  Skipping save...
else
	# no existing save file, save clamscan original file
	echo Saving original ClamAV scanner executable...
	mv $CLAMSCAN_EXE $CLAMSCAN_BACKUP
fi

# remove existing clamscan file or link
echo Replacing clamscan executable with symlink to $UVSCAN_HOME/uvwrap.sh...
rm -f $CLAMSCAN_EXE
ln -s $UVSCAN_HOME/uvwrap.sh $CLAMSCAN_EXE

do_exit 0
