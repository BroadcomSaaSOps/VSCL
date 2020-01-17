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
SCRIPT_ABBR="VSCLUNIN"

# Raw command to remove VSCL from system
UNINSTALL_CMD="$UVSCAN_DIR/uninstall-uvscan"

#=============================================================================
# MAIN
#=============================================================================

Log_Info "==========================="
Log_Info "Beginning VSCL uninstall"
Log_Info "==========================="

# uninstall the uvscan product and remove the uninstaller
if [ ! -d "$UVSCAN_DIR" ]; then
    Exit_WithError "uvscan software not found in '$UVSCAN_DIR'!"
fi

Log_Info "Running uvscan uninstaller..."

if Capture_Command "yes" "| ""$UNINSTALL_CMD"" ""$UVSCAN_DIR"""; then
    if ! rm -rf "$UVSCAN_DIR" &> /dev/null; then
        Log_Info "WARNING: Unable to remove uvscan directory '$UVSCAN_DIR'!"
    fi
else
    Exit_WithError "Error: Unable to remove uvscan software!"
fi

# if [ -w "$CLAMSCAN_BACKUP" ]; then
    # # clamscan was replaced previously
    # # delete the impersonator file or symlink created for uvwrap
    # Log_Info "ClamAV scanner backup detected, restoring..."
    
    # if ! rm -f "$CLAMSCAN_EXE" &> /dev/null; then
        # Log_Info "Warning: Unable to restore original ClamAV scanner!"
    # else
        # # copy original clamscan file back
        # if ! mv "$CLAMSCAN_BACKUP" "$CLAMSCAN_EXE" &> /dev/null; then
            # Log_Info "Warning: Unable to restore original ClamAV scanner!"
        # else
            # if ! chmod +x "$CLAMSCAN_EXE" &> /dev/null; then
                # Log_Info "Warning: Unable to restore original ClamAV scanner!"
            # else
                # Log_Info "Original ClamAV scanner restored!"
            # fi
        # fi
    # fi
# else
    # Log_Info "Warning: ClamAV scanner backup NOT detected!"
# fi

Exit_Script 0
