#!/bin/bash

#=============================================================================
# NAME:		UPDATE-UVSCAN-DAT.SH
# Purpose:	Update the DAT files for the McAfee VirusScan Command Line 
#			Scanner 6.1.0 on SaaS Linux PPM App servers
# Creator:	Nick Taylor, Sr. Engineer, CA SaaS Ops
# Date:		21-Oct-2019
# Version:	1.2
# PreReqs:	Linux
#			CA PPM Application Server
#			VSCL antivirus scanner installed
#			Latest VSCL DAT .ZIP file
#			unzip, tar, gunzip, gclib > 2.7 utilities in OS
# Params:	$1 = VSCL DAT .ZIP file
# Switches: none
# Imports:  none
#=============================================================================


#=============================================================================
# VARIABLES
#=============================================================================
UVSCAN_HOME=/usr/local/uvscan/
IGNORE_FILES=legal.txt

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
echo Beginning VSCL DAT update...
echo $(date +'%x %X')
echo ===========================

if [ ! -f $1 ]; then
	echo ERROR: DAT File \'$1\' does not exist!
	do_exit 1
fi

if [ ! -d $UVSCAN_HOME ]; then
	echo ERROR: uvscan product not found!
	do_exit 1
fi

# unzip DAT into uvscan directory and decompress for use
# (ignore the legal.txt file by default)

echo Unzipping \'$1\' to $UVSCAN_HOME...
unzip -o $1 -x "$IGNORE_FILES" -d $UVSCAN_HOME

echo Decompressing DAT files.  This can take a minute...
$UVSCAN_HOME/uvscan --decompress

do_exit $?