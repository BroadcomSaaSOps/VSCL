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

unset DEBUG_IT LOGFILE
DEBUG_IT=yes
LOGFILE="/tmp/inst-vscl.log"

Debug-Print() {
    #----------------------------------------------------------
    # if 'DEBUG_IT' global is set, print params
    #----------------------------------------------------------

    if [ -n "$DEBUG_IT" ]
    then
        echo -e "$(date +'%x %X') [debug] $@" >> $LOGFILE
    fi
}

#=============================================================================
# VARIABLES
#=============================================================================
unset UVSCAN_HOME TEMP_DIR CLAMAV_HOME CLAMSCAN_EXE CLAMSCAN_BACKUP
unset INSTALLER_ZIP DAT_ZIP INSTALL_CMD DAT_UPDATE_CMD

UVSCAN_HOME=/usr/local/uvscan/
TEMP_DIR=/root/VSCL-TEMP
CLAMAV_HOME=/fs0/od/clamav/bin/
CLAMSCAN_EXE=$CLAMAV_HOME/clamscan
CLAMSCAN_BACKUP=$CLAMSCAN_EXE.orig
INSTALLER_ZIP=(./vscl-*.tar.gz)
DAT_ZIP=(./avvdat-*.zip)
INSTALL_CMD=$TEMP_DIR/install-uvscan
DAT_UPDATE_CMD=./update-uvscan-dat.sh

Debug-Print "UVSCAN_HOME = '$UVSCAN_HOME'"
Debug-Print "TEMP_DIR = '$TEMP_DIR'"
Debug-Print "CLAMAV_HOME = '$CLAMAV_HOME'"
Debug-Print "CLAMSCAN_EXE = '$CLAMSCAN_EXE'"
Debug-Print "CLAMSCAN_BACKUP = '$CLAMSCAN_BACKUP'"
Debug-Print "INSTALLER_ZIP = '$INSTALLER_ZIP'"
Debug-Print "DAT_ZIP = '$DAT_ZIP'"
Debug-Print "INSTALL_CMD = '$INSTALL_CMD'"
Debug-Print "DAT_UPDATE_CMD = '$DAT_UPDATE_CMD'"

#=============================================================================
# FUNCTIONS
#=============================================================================

function do_exit {
	Debug-Print "==========================="
	Debug-Print "$(date +'%x %X')"
	Debug-Print "Ending with exit code: $1"

	exit $1
}

#=============================================================================
# MAIN
#=============================================================================

Debug-Print "Beginning VSCL installation"
Debug-Print "$(date +'%x %X')"
Debug-Print "==========================="

# make temp directory off installer directory
if [ ! -d "$TEMP_DIR" ]
then
	Debug-Print "Creating temp directory '$TEMP_DIR'..."
	mkdir -p "$TEMP_DIR"
fi

# move install files to unzip into temp
if [ -f $INSTALLER_ZIP ]
then
	Debug-Print "Copying install archive '$INSTALLER_ZIP' to temp directory '$TEMP_DIR'..."
	cp $INSTALLER_ZIP $TEMP_DIR
else 
	Debug-Print "ERROR: Installer archive '$INSTALLER_ZIP' does not exist!"
	do_exit 1
fi

# untar installer archive in-place and install uvscan with default settings
Debug-Print Un-tarring VSCL installer $INSTALLER_ZIP...
pushd $TEMP_DIR
tar -xzf $INSTALLER_ZIP

Debug-Print "VSCL install command '$INSTALL_CMD'..."
$INSTALL_CMD -y

# remove temp directory
Debug-Print "Removing temp directory '$TEMP_DIR'..."
popd
#rm -rf $TEMP_DIR

# Run shell file to update the scanner with the latest AV definitions
if [ -f $DAT_ZIP ]
then
	Debug-Print "Unpacking DAT files to uvscan directory..."
	$DAT_UPDATE_CMD $DAT_ZIP
else
	Debug-Print "WARNING: DAT files unavailable for installation!"
fi

# make uvwrap.sh executable and copy to uvscan directory
Debug-Print "Setting up shim wrapper for uvscan..."
chmod +x ./uvwrap.sh
if [ -f $UVSCAN_HOME/uvwrap.sh ]
then 
	rm -f $UVSCAN_HOME/uvwrap.sh
fi

cp ./uvwrap.sh $UVSCAN_HOME

if [ ! -d $CLAMAV_HOME ]
then
	Debug-Print "WARNING: ClamAV home directory '$CLAMAV_HOME' does not exist.  Creating..."
	mkdir -p $CLAMAV_HOME
fi

if [ -f $CLAMSCAN_BACKUP ]
then
	# save file exists, bypass save
	Debug-Print "WARNING: Original ClamAV scanner executable already saved to '$CLAMSCAN_BACKUP'.  Skipping save..."
else
	# no existing save file, save clamscan original file
	Debug-Print "Saving original ClamAV scanner executable..."
	mv $CLAMSCAN_EXE $CLAMSCAN_BACKUP
fi

# remove existing clamscan file or link
Debug-Print "Replacing clamscan executable with symlink to '$UVSCAN_HOME/uvwrap.sh'..."
rm -f $CLAMSCAN_EXE
ln -s $UVSCAN_HOME/uvwrap.sh $CLAMSCAN_EXE

do_exit 0
