#!/bin/bash

#=============================================================================
# NAME:		UVWRAP.SH
# Purpose:	Wrapper to redirect PPM command line antivirus call to McAfee 
#			VirusScan Command Line Scanner 6.1.0 on SaaS Linux PPM App servers
# Creator:	Nick Taylor, Sr. Engineer, CA SaaS Ops
# Date:		22-May-2017
# Version:	1.1
# PreReqs:	Linux
#			CA PPM Application Server
#			ClamAV antivirus scanner installed and integrated with PPM
#				default install directory: /fs0/od/clamav/bin
#			VSCL installed and integrated with PPM
#			unzip, tar, gunzip, gclib > 2.7 utilities in OS
#=============================================================================
# Params:	$1 = full path of file to be scanned (supplied by PPM) 
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================
UVSCAN_HOME=/usr/local/uvscan/

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
echo Beginning command line scan...
echo $(date +'%x %X')
echo ===========================

if [ "-$@-" == "--" ]
then
	# exit if no file specified
    echo ERROR: No command line parameters supplied!
    do_exit 1
else
	echo Parameter supplied: \'$1\'
fi

# call uvscan
$UVSCAN_HOME/uvscan -c -p --afc 512 -e --nocomp --ignore-links --noboot --nodecrypt --noexpire --one-file-system --timeout 10 "$@"
# -c 					clean viruses if found
# -p					
# --afc 512				half-meg buffers
# -e					
# --nocomp				don't scan compressed files
# --ignore-links		ignore symlinks
# --noboot				don't scan boot sectors
# --nodecrypt			do not decrypt files
# --noexpire			no error for expired files
# --one-file-system		do not follow mouned directory trees
# --timeout 10			scan for 10 seconds then abort

if [ $? -ne 0 ]
then
	# uvscan returned anything other than 0, exit and return 1
	echo *** Virus found! ***
    do_exit 1
fi

# exit successfully
echo NO virus found!

do_exit 0
