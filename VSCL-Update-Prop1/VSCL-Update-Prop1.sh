#!/bin/bash

#=============================================================================
# NAME:         update-prop1.sh
# Purpose:      Update the McAfee custom property #1 with the current 
#               version of the DAT files for the McAfee VirusScan Command Line
#               Scanner 6.1.0 on SaaS Linux PPM App servers
# Creator:      Nick Taylor, Sr. Engineer, CA SaaS Ops
# Original:     Copyright (c) 2009 McAfee, Inc. All Rights Reserved.
# Date:         21-OCT-2017
# Version:      1.0
# PreReqs:      Linux
#               CA PPM Application Server
#               VSCL antivirus scanner installed
#               Latest VSCL DAT .ZIP file
#               unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#               awk, echo, cut, ls, printf
# Params:       none
# Switches:     -d:  download current DATs and exit
#               -l:  leave any files extracted intact at exit
# Imports:      none
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================

# Defaults: Do not modify
#-----------------------------------------
unset DEBUG_IT SCRIPT_NAME UVSCAN_EXE UVSCAN_DIR MACONFIG_PATH CMDAGENT_PATH CURRENT_DAT DEBUG_LOG

# Globals
# (these variables are normally best left unmodified)
#-----------------------------------------
# name of this script
SCRIPT_NAME=`basename "$0"`

# name of scanner executable
UVSCAN_EXE="uvscan"

# Change these variables to match your environment
# UVSCAN_DIR must be a directory and writable where uvscan is installed
UVSCAN_DIR="/usr/local/uvscan"

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

# Preferences
#-----------------------------------------
# show debug messages (set to non-empty to enable)
DEBUG_IT=yes
DEBUG_LOG=/var/McAfee/agent/logs/VSCL_mgmt.log

#=============================================================================
# FUNCTIONS
#=============================================================================


Exit-WithError() {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
	# Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [ -n "$1" ]
    then
        Debug-Print "$SCRIPT_NAME: $1\n"
    fi

    exit 1
}


Debug-Print() {
    #----------------------------------------------------------
    # If 'DEBUG_IT' global is set, print error message
    #----------------------------------------------------------
	# Params: $1 = error message to print
    #----------------------------------------------------------

    if [ -n "$DEBUG_IT" ]
    then
        printf "$SCRIPT_NAME: [debug] $@\n" >> $DEBUG_LOG
    fi
	
	return 0
}


Get-CurrentDATVersion() {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    unset UVSCAN_DAT LOCAL_DAT_VERSION LOCAL_ENG_VERSION
	UVSCAN_DAT=`("$UVSCAN_DIR/$UVSCAN_EXE" --version)`

    if [ $? -ne 0 ]
    then
        return 1
    fi

    LOCAL_DAT_VERSION=`printf "$UVSCAN_DAT\n" | grep -i "dat set version:" | cut -d' ' -f4`
	LOCAL_ENG_VERSION=`printf "$UVSCAN_DAT\n" | grep -i "av engine version:" | cut -d' ' -f4`
    printf "${LOCAL_DAT_VERSION}.0 (${LOCAL_ENG_VERSION})\n"

    return 0
}


Refresh-ToEPO() {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------

	# flags to use with CMDAGENT utility
	unset CMDAGENT_FLAGS
	CMDAGENT_FLAGS="-c -f -p -e"

    Debug-Print "Refreshing agent data with EPO..."
	
    # loop through provided flags and call one command per
	# (CMDAGENT can't handle more than one)
	for FLAG_NAME in $CMDAGENT_FLAGS
    do
        $CMDAGENT_PATH $FLAG_NAME
		
		if [ $? -ne 0 ]
		then
			Exit-WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'!"
		fi
    done
	
	return 0
}


Check-For() {
    #------------------------------------------------------------
    # Function to check for existence of a file
	#------------------------------------------------------------
	# Params:  $1 = full path to file
	#          $2 = friendly-name of file
	#          $3 = (optional) --no-terminate to return always
    #------------------------------------------------------------
	Debug-Print "Checking for '$2' at '$1'..."

	if [ ! -x "$1" ]
	then
		if [ "$3" = "--no-terminate" ]
		then
			return 1
		else
			Exit-WithError "Could not find '$2' at '$1'!"
		fi
	fi
	
	return 0
}


Set-CustomProp1() {
    #------------------------------------------------------------
    # Set the value of McAfee custom Property #1
	#------------------------------------------------------------
	# Params:  $1 = value to set property
    #------------------------------------------------------------
	Debug-Print "Setting EPO Custom Property #1 to '$1'..."

	$MACONFIG_PATH -custom -prop1 "$1"

	if [ $? -ne 0 ]
	then
		Exit-WithError "Error setting EPO Custom Property #1 to '$1'!"
	fi
	
	return 0
}


#=============================================================================
#  MAIN PROGRAM
#=============================================================================

# sanity checks
# check for MACONFIG
Check-For $MACONFIG_PATH "MACONFIG utility"

# check for CMDAGENT
Check-For $CMDAGENT_PATH "CMDAGENT utility"

# check for uvscan
Check-For $UVSCAN_DIR/$UVSCAN_EXE "uvscan executable" --no-terminate

if [ $? -ne 0 ]
then
	# uvscan not found
	# set custom property to error value, then exit with error
    Debug-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
	CURRENT_DAT="VSCL:NOT INSTALLED"
else
	# Get the version of the installed DATs...
	Debug-Print "Determining the currently DAT version..."
	CURRENT_DAT=`Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE"`

	if [ -z "$CURRENT_DAT" ]
	then
		# Could not determine current value for DAT version from uvscan
		# set custom property to error value, then exit with error
		Debug-Print "Unable to determine currently installed DAT version!"
		CURRENT_DAT="VSCL:INVALID DAT"
	else
		CURRENT_DAT="VSCL=$CURRENT_DAT"
	fi
fi

Debug-Print "Setting McAfee Custom Property #1 to '$CURRENT_DAT'..."
Set-CustomProp1 "$CURRENT_DAT"
Refresh-ToEPO	
exit 0
