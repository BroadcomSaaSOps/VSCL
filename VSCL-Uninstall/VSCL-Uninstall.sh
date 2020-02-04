#!/bin/bash

#=============================================================================
# NAME:     UNINSTALL-VSCL.SH
#-----------------------------------------------------------------------------
# Purpose:  Uninstall the McAfee VirusScan Command Line Scanner v6.1.0
#           from SaaS Linux PPM App servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     03-FEB-2020
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
# Imports:  ./VSCL-lib.sh:              library functions
#           ./VSCL-Update-Prop1.sh:     self-contained Custom Prop #1 updater
#=============================================================================


#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Uninstaller must NOT be sourced.  It must be run standalone!"
    return
fi


#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
. ./VSCL-lib.sh
# shellcheck disable=SC1091
. ./VSCL-Update-Prop1.sh


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCLUNIN"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function Uninstall_VSCL {
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

    Update_Prop1
    return $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
Uninstall_VSCL

# Clean up global variables and exit cleanly
Exit_Script $?
