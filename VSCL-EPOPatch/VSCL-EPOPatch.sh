#!/bin/bash

#=============================================================================
# NAME:     VSCL-EPOPatch.sh
#-----------------------------------------------------------------------------
# Purpose:  Patch for McAfee VirusScan Command Line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     06-FEB-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           PPM Application Server
#           ClamAV antivirus scanner installed and integrated with PPM
#               default install directory: /fs0/od/clamav/bin
#           VSCL installer available in EPO (VSCLPACKxxxx)
#           Latest VSCL DAT .ZIP file available in EPO (VSCANDATxxxx)
#           VSCL-Download-DAT.sh in directory
#           uvwrap.sh in directory
#           unzip, tar, gunzip, gclib (> 2.7) utilities in OS
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:              library functions
#=============================================================================


#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
# shellcheck disable=SC2091
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Patch must NOT be sourced. It must be run standalone. Aborting installer!"
    return 1
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
INCLUDE_PATH="${BASH_SOURCE%/*}"
. "$INCLUDE_PATH/VSCL-lib.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCLEPAT"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function Install_Patch {
    #----------------------------------------------------------
    # Download the latest installer from EPO and run it
    #----------------------------------------------------------
    # Params: $@ - all arguments passed to script
    #----------------------------------------------------------
    local SUPPORT_FILE TARGET_FILE

    # Copy support files to uvscan directory
    for SUPPORT_FILE in $__VSCL_SCAN_SUPPORT_FILES; do
        TARGET_FILE="$__VSCL_UVSCAN_DIR/$SUPPORT_FILE"
        Log_Info "Copying support file '$SUPPORT_FILE' to '$TARGET_FILE'..."

        if [[ ! -f "./$SUPPORT_FILE" ]]; then
            # source support file not available, error
            Exit_WithError "File '$SUPPORT_FILE' not available. Aborting installer!"
        fi

        if [[ -f "$TARGET_FILE" ]]; then
            # delete any existing copy of support file
            Log_Info "Deleting existing file '$TARGET_FILE'..."
            
            if ! rm -f "$TARGET_FILE"; then
                # unable to remove target file, error
                Log_Error "Existing file '$TARGET_FILE' could not be deleted! Aborting installer!"
            fi
        fi

        if ! cp -f "./$SUPPORT_FILE" "$__VSCL_UVSCAN_DIR"; then
            # error copying support file to target, error
            Exit_WithError "Could not copy support file './$SUPPORT_FILE' to '$__VSCL_UVSCAN_DIR/$SUPPORT_FILE'. Aborting installer!"
        fi

        if ! chmod +x "$__VSCL_UVSCAN_DIR/$SUPPORT_FILE"; then
            # unable to make target support file executable, error
            Exit_WithError "File '$SUPPORT_FILE' not available. Aborting installer!"
        fi
    done

    # Clean up global variables and exit cleanly
    Exit_Script $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
Install_Patch "$@"
