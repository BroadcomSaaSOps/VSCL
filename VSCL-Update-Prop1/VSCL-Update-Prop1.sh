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
#-----------------------------------------------------------------------------
# Imports:      ./VSCL-local.sh:  library functions
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
. ./VSCL-lib.sh

#-----------------------------------------
# Globals variables
#-----------------------------------------
# name of this script
SCRIPT_ABBR="VSCL_UP1"

#-----------------------------------------
# Functions
#-----------------------------------------

function Get-CurrentDATVersion() {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    unset UVSCAN_DAT LOCAL_DAT_VERSION LOCAL_ENG_VERSION
    UVSCAN_DAT=`("$UVSCAN_DIR/$UVSCAN_EXE" --version)`

    if [ $? -ne 0 ]; then
        return 1
    fi

    LOCAL_DAT_VERSION=`printf "$UVSCAN_DAT\n" | grep -i "dat set version:" | cut -d' ' -f4`
    LOCAL_ENG_VERSION=`printf "$UVSCAN_DAT\n" | grep -i "av engine version:" | cut -d' ' -f4`
    printf "${LOCAL_DAT_VERSION}.0 (${LOCAL_ENG_VERSION})\n"
    Log-Print "${LOCAL_DAT_VERSION}.0 (${LOCAL_ENG_VERSION})\n"

    return 0
}

function Set-CustomProp1() {
    #------------------------------------------------------------
    # Set the value of McAfee custom Property #1
    #------------------------------------------------------------
    # Params:  $1 = value to set property
    #------------------------------------------------------------
    Log-Print "Setting EPO Custom Property #1 to '$1'..."

    $MACONFIG_PATH -custom -prop1 "$1" >>"$LOG_PATH" 2>&1

    if [ $? -ne 0 ]; then
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

if [ $? -ne 0 ]; then
    # uvscan not found
    # set custom property to error value, then exit with error
    Log-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
    CURRENT_DAT="VSCL:NOT INSTALLED"
else
    # Get the version of the installed DATs...
    Log-Print "Determining the currently DAT version..."
    CURRENT_DAT=`Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE"`

    if [[ -z "$CURRENT_DAT" ]]; then
        # Could not determine current value for DAT version from uvscan
        # set custom property to error value, then exit with error
        Log-Print "Unable to determine currently installed DAT version!"
        CURRENT_DAT="VSCL:INVALID DAT"
    else
        CURRENT_DAT="VSCL:$CURRENT_DAT"
    fi
fi

# Set custom property #1 and push to EPO, then exit cleanly
Set-CustomProp1 "$CURRENT_DAT"
Refresh-ToEPO   
Exit-Script 0
