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

# UVSCAN_DIR must be a directory and writable where uvscan is installed
UVSCAN_DIR="/usr/local/uvscan"

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

# TMP_DIR must be a directory and writable
TMP_DIR=$(mktemp -d -p "$SCRIPT_PATH" 2> /dev/null)

if [[ ! -d "$TMP_DIR" ]];then
    Exit-WithError "Unable to create temporary directory '$TMP_DIR'"
fi

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
    #Log-Print $SCRIPT_NAME
    #Log-Print $SCRIPT_PATH
    #Log-Print $SCRIPT_ABBR
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

function Log-Print() {
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
    local CMDAGENT_FLAGS OUT ERR CMDSTR
    CMDAGENT_FLAGS="-c -f -p -e"

    Log-Print "Refreshing agent data with EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAG_NAME in $CMDAGENT_FLAGS; do
        unset OUT
        CMDSTR="$CMDAGENT_PATH $FLAG_NAME"
        Log-Print ">> cmd = '$CMDSTR'"
        
        if command -v readarray &> /dev/null; then
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


function Find-INISection() {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Output: space-delimited INI entries
    #----------------------------------------------------------

    unset SECTION_FOUND

    SECTION_NAME="[$1]"

    while read -r LINE; do
        if [[ "$LINE" = "$SECTION_NAME" ]]; then
            SECTION_FOUND="true"
        elif [[ -n "$SECTION_FOUND" ]]; then
            if [[ "$(echo "$LINE" | cut -c1)" != "[" ]]; then
                if [[ -n "$LINE" ]]; then
                    printf "%s\n" "$LINE"
                fi
            else
                unset SECTION_FOUND
            fi
        fi
    done
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


function Set-CustomProp() {
    #------------------------------------------------------------
    # Set the value of McAfee custom Property #1
    #------------------------------------------------------------
    # Params: $1 = number of property to set (1-8) 
    #         $2 = value to set property
    #------------------------------------------------------------
    local CMDSTR

    Log-Print "Setting EPO Custom Property #$1 to '$2'..."

    CMDSTR="$MACONFIG_PATH"
    CMDARGS="-custom -prop$1 '$2'"
    Log-Print ">> cmd = '$CMDSTR $CMDARGS'"

    if command -v readarray &> /dev/null; then
        readarray -t OUT < <($MACONFIG_PATH -custom -prop$1 "$2")
        ERR=$?
    else
        IFS=$'\n'
        OUT=($($MACONFIG_PATH -custom -prop$1 "$2"))
        ERR=$?
        unset IFS
    fi

    for output in "${OUT[@]}"; do
        Log-Print ">> $output"
    done

    if [ $? -ne 0 ]; then
        Exit-WithError "Error setting EPO Custom Property #$1 to '$2'!"
    fi
    
    return 0
}


function Get-CurrentDATVersion() {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    local UVSCAN_DAT LOCAL_DAT_VERSION LOCAL_ENG_VERSION OUTPUT
    UVSCAN_DAT=$("$UVSCAN_DIR/$UVSCAN_EXE" --version)

    if [ $? -ne 0 ]; then
        return 1
    fi

    LOCAL_DAT_VERSION=$(printf "%s" "$UVSCAN_DAT" | grep -i "dat set version:" | cut -d' ' -f4)
    LOCAL_ENG_VERSION=$(printf "%s" "$UVSCAN_DAT" | grep -i "av engine version:" | cut -d' ' -f4)
    OUTPUT=$(printf "%s.0 (%s)" "$LOCAL_DAT_VERSION" "$LOCAL_ENG_VERSION")
    printf "%s" "$OUTPUT"

    return 0
}



function Download-File() {
    #------------------------------------------------------------
    # Function to download a specified file from repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #------------------------------------------------------------

    local FILE_NAME DOWNLOAD_URL FETCHER_CMD FETCHER

    # sanity checks
    # check for wget
    if command -v wget 2> /dev/null; then
        FETCHER="wget"
    elif command -v curl 2> /dev/null; then
        FETCHER="curl"
    else
        Exit-WithError "No valid URL fetcher available!"
    fi

    # type must be "bin" or "ascii"
    if [[ "$3" != "bin" ]] && [[ "$3" != "ascii" ]]; then
        Exit-WithError "Download type must be 'bin' or 'ascii'!"
    fi

    FILE_NAME="$4/$2"
    DOWNLOAD_URL="$1/$2"

    # download with wget
    case $FETCHER in
        "wget") FETCHER_CMD="wget -q --tries=10 --no-check-certificate ""$DOWNLOAD_URL"" -O ""$FILE_NAME"""
            ;;
        "curl") FETCHER_CMD="curl -s -k ""$DOWNLOAD_URL"" -o ""$FILE_NAME"""
            ;;
        *) Exit-WithError "No valid URL fetcher available!"
            ;;
    esac

    
    #FETCH_RESULT="$?"

    if $FETCHER_CMD; then
        #ls -lAh "$4"
        
        # file downloaded OK
        if [[ "$3" = "ascii" ]]; then
            # strip and CR/LF line terminators
            tr -d '\r' < "$FILE_NAME" > "$FILE_NAME.tmp"
            rm -f "$FILE_NAME"
            mv "$FILE_NAME.tmp" "$FILE_NAME"
        fi
        
        return 0
    fi
    
    return 1
}


Validate-File() {
    #------------------------------------------------------------
    # Function to check the specified file against its expected
    # size, checksum and MD5 checksum.
    #------------------------------------------------------------
    # Params: $1 - File name (including path)
    #         $2 - expected size
    #         $3 - MD5 Checksum
    #------------------------------------------------------------

    local SIZE MD5_CSUM MD5CHECKER
        
    # Optional: Program for calculating the MD5 for a file
    MD5CHECKER="md5sum"

    # Check the file size matches what we expect...
    SIZE=$(stat "$1" --printf "%s")

    if [[ -n "$SIZE" ]] && [[ "$SIZE" = "$2" ]]; then
        Log-Print "File '$1' size is correct ($2)"
    else
        Exit-WithError "Downloaded DAT size '$SIZE' should be '$1'!"
    fi

    # make MD5 check optional. return "success" if there's no support
    if [[ -z "$MD5CHECKER" ]] || [[ ! -x $(command -v $MD5CHECKER 2> /dev/null) ]]; then
        Log-Print "MD5 Checker not available, skipping MD5 check..."
        return 0
    fi

    # Check the MD5 checksum...
    MD5_CSUM=$($MD5CHECKER "$1" 2>/dev/null | cut -d' ' -f1)

    if [[ -n "$MD5_CSUM" ]] && [[ "$MD5_CSUM" = "$3" ]]; then
        Log-Print "File '$1' MD5 checksum is correct ($3)"
    else
        Exit-WithError "Downloaded DAT MD5 hash '$MD5_CSUM' should be '$3'!"
    fi

    return 0
}
