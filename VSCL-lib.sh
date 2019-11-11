#!/bin/bash

#=============================================================================
# NAME:         VSCL-lib.sh
#-----------------------------------------------------------------------------
# Purpose:      Shared code for VSCL management scripts
#-----------------------------------------------------------------------------
# Creator:      Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:         07-NOV-2019
#-----------------------------------------------------------------------------
# Version:      1.2
#-----------------------------------------------------------------------------
# PreReqs:      none
#-----------------------------------------------------------------------------
# Params:       none
#-----------------------------------------------------------------------------
# Switches:     none
#-----------------------------------------------------------------------------
# Imports:      none
#=============================================================================

#-----------------------------------------
# Globals variables
#-----------------------------------------
# name of script file
SCRIPT_NAME=$(basename "$0")
# path to script file
SCRIPT_PATH=$(dirname "$0")
# show debug messages (set to non-empty to enable)
DEBUG_IT=yes
# Path to common log file
LOG_PATH="/var/McAfee/agent/logs/VSCL_mgmt.log"
# name of scanner executable
UVSCAN_EXE="uvscan"

# Change these variables to match your environment
# UVSCAN_DIR must be a directory and writable where uvscan is installed
UVSCAN_DIR="/usr/local/uvscan"

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

#-----------------------------------------
# Library functions
#-----------------------------------------

Do-Cleanup() {
    #------------------------------------------------------------
    # if 'LEAVE_FILES' global is NOT set, erase downloaded files
    #------------------------------------------------------------

    if [[ -z "$LEAVE_FILES" ]]; then
        if [[ -z "$TMP_DIR" ]]; then
            rm -rf "$TMP_DIR"
        fi
    fi
}

function Exit-Script() {
    #----------------------------------------------------------
    # Params: $1 = exit code (assumes 0/ok)
    #----------------------------------------------------------

    local OUTCODE

    Log-Print "==========================="

    if [[ -z "$1" ]]; then
        OUTCODE="0"
    else
        if [ "$1" != "0" ]; then
            OUTCODE="$1"
        fi
    fi
    
    Log-Print "Ending with exit code: $1"
    Log-Print "==========================="
    Log-Print $SCRIPT_NAME
    Log-Print $SCRIPT_PATH
    Log-Print $SCRIPT_ABBR
    exit $OUTCODE
}

function Exit-WithError() {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
    # Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [[ -n "$1" ]]; then
        Log-Print "$1"
    fi

    Do-Cleanup
    Exit-Script 1
}

Log-Print() {
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    local OUTPUT
    OUTPUT="$(date +'%x %X'):$SCRIPT_ABBR:$*"

    if [[ -f $LOG_PATH ]]; then
        echo "$OUTPUT" | tee --append "$LOG_PATH"
    else
        echo "$OUTPUT" | tee "$LOG_PATH"
    fi
    
    return 0
}

function Check-For() {
    #------------------------------------------------------------
    # Function to check for existence of a file
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) --no-terminate to return always
    #------------------------------------------------------------
    Log-Print "Checking for '$2' at '$1'..."

    if [[ ! -x "$1" ]]; then
        if [[ "$3" = "--no-terminate" ]]; then
            return 1
        else
            Exit-WithError "Could not find '$2' at '$1'!"
        fi
    fi
    
    return 0
}

function Refresh-ToEPO() {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------

    # flags to use with CMDAGENT utility
    local CMDAGENT_FLAGS OUT ERR
    CMDAGENT_FLAGS="-c -f -p -e"

    Log-Print "Refreshing agent data with EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAG_NAME in $CMDAGENT_FLAGS; do
        unset OUT
        Log-Print ">> cmd = '$CMDAGENT_PATH $FLAG_NAME'"
        
        if command -v readarray; then
            readarray -t OUT < <($CMDAGENT_PATH $FLAG_NAME)
            ERR=$?
        else
            IFS=$'\n'
            OUT=($($CMDAGENT_PATH $FLAG_NAME))
            ERR=$?
            unset IFS
        fi

        for output in "${OUT[@]}"; do
            Log-Print ">> $output"
        done
        
        if [ $ERR -ne 0 ]; then

            Exit-WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'\!"
        fi
    done
    
    return 0
}
