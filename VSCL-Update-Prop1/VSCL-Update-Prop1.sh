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
# shellcheck disable=SC1091
. ./VSCL-lib.sh

#-----------------------------------------
# Globals variables
#-----------------------------------------
# name of this script
# shellcheck disable=SC2034
SCRIPT_ABBR="VSCL_UP1"

#=============================================================================
#  MAIN PROGRAM
#=============================================================================

# sanity checks
# check for MACONFIG
Check-For "$MACONFIG_PATH" "MACONFIG utility"

# check for CMDAGENT
Check-For "$CMDAGENT_PATH" "CMDAGENT utility"

# check for uvscan
if ! Check-For "$UVSCAN_DIR/$UVSCAN_EXE" "uvscan executable" --no-terminate; then
    # uvscan not found
    # set custom property to error value, then exit with error
    Log-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
    CURRENT_DAT="VSCL:NOT INSTALLED"
else
    # Get the version of the installed DATs...
    Log-Print "Determining the current DAT version..."
    CURRENT_DAT=$(Get-CurrentDATVersion)

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
Set-CustomProp 1 "$CURRENT_DAT"
Refresh-ToEPO   
Exit-Script 0
