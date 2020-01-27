#!/bin/bash

#=============================================================================
# NAME:     update-prop1.sh
#-----------------------------------------------------------------------------
# Purpose:  Update the McAfee custom property #1 with the current 
#           version of the DAT files for the McAfee VirusScan Command Line
#           Scanner 6.1.0 on SaaS Linux PPM App servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     17-JAN-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL antivirus scanner installed
#           Latest VSCL DAT .ZIP file
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#           awk, echo, cut, ls, printf
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:  library functions
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
# shellcheck disable=SC1091
. ./VSCL-lib.sh

#-----------------------------------------
# Global variables
#-----------------------------------------
# name of this script
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCL_UP1"

#=============================================================================
#  MAIN PROGRAM
#=============================================================================

# sanity checks
# check for MACONFIG
Check_For "$__VSCL_MACONFIG_PATH" "MACONFIG utility"

# check for CMDAGENT
Check_For "$__VSCL_CMDAGENT_PATH" "CMDAGENT utility"

# check for uvscan
if ! Check_For "$__VSCL_UVSCAN_DIR/$__VSCL_UVSCAN_EXE" "uvscan executable" --no-terminate; then
    # uvscan not found
    # set custom property to error value, then exit with error
    Log_Info "Could not find 'uvscan executable' at '$__VSCL_UVSCAN_DIR/$__VSCL_UVSCAN_EXE'!"
    CURRENT_DAT="VSCL:NOT INSTALLED"
else
    # Get the version of the installed DATs...
    Log_Info "Determining the current DAT version..."
    CURRENT_DAT=$(Get_CurrDATVer)

    if [[ -z "$CURRENT_DAT" ]]; then
        # Could not determine current value for DAT version from uvscan
        # set custom property to error value, then exit with error
        Log_Info "Unable to determine currently installed DAT version!"
        CURRENT_DAT="VSCL:INVALID DAT"
    else
        CURRENT_DAT="VSCL:$CURRENT_DAT"
    fi
    
    Log_Info "Current DAT Version is '$CURRENT_DAT'"
fi

# Set custom property #1 and push to EPO, then exit cleanly
Set_CustomProp 1 "$CURRENT_DAT"
Refresh_ToEPO   
Exit_Script 0
