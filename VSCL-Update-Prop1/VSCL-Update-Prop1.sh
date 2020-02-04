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
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
if [[ -z "$__VSCL_UP1_LOADED" ]]; then
    # not already loaded, set flag that it is now
    #echo "not loaded, loading..."
    __VSCL_UP1_LOADED=1
else
    # already loaded, exit gracefully
    #echo "loaded already"
    return 0
fi


#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
. ./VSCL-lib.sh


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
if [[ -z "$__VSCL_SCRIPT_ABBR" ]]; then
    __VSCL_SCRIPT_ABBR="VSCL_UP1"
fi


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function Update_Prop1 {
    local CURRENT_DAT
    
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
        CURRENT_DAT="$__VSCL_NOTINST_CODE"
    else
        # Get the version of the installed DATs...
        Log_Info "Determining the current DAT version..."
        CURRENT_DAT=$(Get_CurrDATVer)

        if [[ "$CURRENT_DAT" = "$__VSCL_INVALID_CODE" ]]; then
            # Could not determine current value for DAT version from uvscan
            # set custom property to error value, then exit with error
            Log_Info "Unable to determine currently installed DAT version!"
            CURRENT_DAT="$__VSCL_INVALID_CODE"
        else
            CURRENT_DAT="VSCL:$CURRENT_DAT"
        fi
        
        Log_Info "Current DAT Version is '$CURRENT_DAT'"
    fi

    # Set custom property #1 and push to EPO, then exit cleanly
    Set_CustomProp 1 "$CURRENT_DAT"
    Refresh_ToEPO   
    return $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
if $(return 0 2>/dev/null); then
    # File is sourced, return to sourcing code
    #Log_Info "VSCL Update Custom Property functions loaded successfully!"
    return 0
else
    # File is NOT sourced, execute it like it any regular shell file
    Update_Prop1
    
    # Clean up global variables and exit cleanly
    Exit_Script $?
fi
