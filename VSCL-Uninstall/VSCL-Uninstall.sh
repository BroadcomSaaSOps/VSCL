#!/bin/bash

#=============================================================================
# NAME:     UNINSTALL-VSCL.SH
#-----------------------------------------------------------------------------
# Purpose:  Uninstall the McAfee VirusScan Command Line Scanner v6.1.0
#           from SaaS Linux PPM App servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     14-NOV-2019
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           PPM Application Server
#           VSCL installed
#           unzip, tar, gunzip, gclib (> 2.7) utilities in OS
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:    library functions
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
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCLUNIN"


#=============================================================================
# MAIN
#=============================================================================

Log_Info "==========================="
Log_Info "Beginning VSCL uninstall"
Log_Info "==========================="

#echo "\$__VSCL_UVSCAN_DIR = '$__VSCL_UVSCAN_DIR'"

# uninstall the uvscan product and remove the uninstaller
if [ ! -d "$__VSCL_UVSCAN_DIR" ]; then
    Exit_WithError "VSCL software directory not found in '$__VSCL_UVSCAN_DIR'!"
fi

Log_Info "Running VSCL uninstaller..."

if Capture_Command "$__VSCL_UNINSTALL_CMD" "" "/usr/bin/yes"; then
    #echo "\$__VSCL_UVSCAN_DIR = '$__VSCL_UVSCAN_DIR'"
    if ! rm -rf "$__VSCL_UVSCAN_DIR" &> /dev/null; then
        Log_Warning "Unable to remove VSCL software directory '$__VSCL_UVSCAN_DIR'!"
    fi
else
    Exit_WithError "Unable to uninstall VSCL software!"
fi

Log_Info "Setting McAfee Custom Property #1 to 'VSCL:NOT INSTALLED'..."
Set_CustomProp 1 "VSCL:NOT INSTALLED"
Refresh_ToEPO
Exit_Script 0
