#!/bin/bash

#=============================================================================
# NAME:     UVWRAP.SH
#-----------------------------------------------------------------------------
# Purpose:  __VSCL_WRAPPER to redirect PPM command line antivirus call to McAfee 
#           VirusScan Command Line Scanner
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     07-Feb-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL installed and integrated with PPM
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS
#-----------------------------------------------------------------------------
# Params:   $1 = full path of file to be scanned (supplied by PPM) 
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  none
#=============================================================================
# NOTES: Fixed for Commercial to not require the VSCL library

#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Installer must NOT be sourced.  It must be run standalone!"
    return 1
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
unset INCLUDE_PATH THIS_FILE
THIS_FILE="${BASH_SOURCE[0]}"
THIS_FILE=$(while [[ -L "$THIS_FILE" ]]; do THIS_FILE="$(readlink "$THIS_FILE")"; done; echo $THIS_FILE)
INCLUDE_PATH="${THIS_FILE%/*}"
. "$INCLUDE_PATH/VSCL-lib.sh"

#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="UVWRAP"

# Path to common log file for all VSCL scripts
__VSCL_LOG_PATH="/var/McAfee/agent/logs/VSCL_mgmt.log"

# Options passed to VSCL scanner
# -c                    clean viruses if found
# -p                    
# --afc 512             half-meg buffers
# -e                    
# --nocomp              don't scan compressed files
# --ignore-links        ignore symlinks
# --noboot              don't scan boot sectors
# --nodecrypt           do not decrypt files
# --noexpire            no error for expired files
# --one-file-system     do not follow mouned directory trees
# --timeout 10          scan for 10 seconds then abort
SCAN_OPTIONS="-c -p --afc 512 -e --nocomp --ignore-links --noboot --nodecrypt --noexpire --one-file-system --timeout 10"


#=============================================================================
# FUNCTIONS: VSCL Library functions
#=============================================================================

function Log_Print {
    #----------------------------------------------------------
    # Print a message to the log defined in $__VSCL_LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    local OUTTEXT #SAVE_OPTS
    
    #SAVE_OPTS=$SHELLOPTS
    #set +x
    
    # Prepend date/time, which script, then the log message
    # i.e.  "11/12/2019 11:14:10 AM:VSCL_UP1:[x]Refreshing agent data with EPO..."
    #        <- date -------------> <script> <+><-- message -->
    #                                         ^-- log mode "I": info, "W": warning, "E": errror
    OUTTEXT="$(date +'%x %X'):$__VSCL_SCRIPT_ABBR:$*"

    if [[ -w $__VSCL_LOG_PATH ]]; then
        # log file exists and is writable, append
        #echo -e "$OUTTEXT" | tee --append "$__VSCL_LOG_PATH"
        printf "%s\n" "$OUTTEXT" | tee --append "$__VSCL_LOG_PATH"
    else
        # log file absent, create
        #echo -e "$OUTPUT" | tee "$__VSCL_LOG_PATH"
        printf "%s\n" "$OUTTEXT" | tee "$__VSCL_LOG_PATH"
    fi
    
    #if [[ "$SAVE_OPTS" == *"xtrace"* ]]; then
    #    set -x
    #fi
    
    return 0
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
Log_Print "=============================="
Log_Print "Beginning command line scan..."
Log_Print "=============================="

if [[ -z "$*" ]]; then
    # exit if no file specified
    Log_Print "[E]No command line parameters supplied!"
    exit 1
else
    Log_Print "Parameters supplied: '$*'"
fi

# call uvscan
if ! /usr/local/uvscan/uvscan $SCAN_OPTIONS $*; then
    # uvscan returned error, exit and return 1
    Log_Print "[E]*** Virus found! ***"
    exit 1
fi

# No virus found, exit successfully
Log_Print "[I]*** No virus found! ***"
exit 0
