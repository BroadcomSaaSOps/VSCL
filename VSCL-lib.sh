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
# Imports:      none
#=============================================================================

#----------------------------------------------------------------
# Globals variables used by all scripts this import this library
#----------------------------------------------------------------
# name of script file (the one that dotsourced this library, not the library itself)
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")

# path to script file (the one that dotsourced this library, not the library itself)
SCRIPT_PATH=$(dirname "$0")

# show debug messages (set to non-empty to enable)
DEBUG_IT=yes

# flag to erase any temp files on exit (set to non-empty to enable)
#LEAVE_FILES=

# Path to common log file for all VSCL scripts
LOG_PATH="/var/McAfee/agent/logs/VSCL_mgmt.log"

# name of VSCL scanner executable
UVSCAN_EXE="uvscan"

# UVSCAN_DIR must be a directory and writable where VSCL is installed
UVSCAN_DIR="/usr/local/uvscan"

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

#-----------------------------------------
# VSCL Library functions
#-----------------------------------------

function Do-Cleanup {
    #------------------------------------------------------------
    # if 'LEAVE_FILES' global is NOT set, erase downloaded files
    #------------------------------------------------------------

    if [[ -z "$LEAVE_FILES" ]]; then
        if [[ -z "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR"
        fi
    fi
}

function Exit-Script {
    #------------------------------------------------------------
    # Exit the script with an exit code
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
    # shellcheck disable=SC2086
    exit $OUTCODE
}

function Exit-WithError {
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

function Log-Print {
    #----------------------------------------------------------
    # Print a message to the log defined in $LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    local OUTPUT
    
    # Prepend date/time, which script, then the log message
    # i.e.  "11/12/2019 11:14:10 AM:VSCL_UP1:Refreshing agent data with EPO..."
    #        <- date -------------> <script> <-- message -->
    OUTPUT="$(date +'%x %X'):$SCRIPT_ABBR:$*"

    if [[ -w $LOG_PATH ]]; then
        # log file exists and is writable, append
        echo "$OUTPUT" | tee --append "$LOG_PATH"
    else
        # log file absent, create
        echo "$OUTPUT" | tee "$LOG_PATH"
    fi
    
    return 0
}


function Refresh-ToEPO {
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
        Log-Print ">> cmd = '$CMDAGENT_PATH $FLAG_NAME'"
        
        # run command and capture output
        IFS=$'\n'
        read -r -a OUT < <($CMDAGENT_PATH "$FLAG_NAME")
        ERR=$?
        unset IFS

        for output in ${OUT[*]}; do
            # append output to log
            Log-Print ">> $output"
        done
        
        if [ $ERR -ne 0 ]; then
            # error, exit sctipt
            Exit-WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'\!"
        fi
    done
    
    return 0
}


function Find-INISection {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Output: space-delimited INI entries
    #----------------------------------------------------------

    local SECTION_FOUND

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


function Check-For {
    #------------------------------------------------------------
    # Function to check that a file is available and executable
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) --no-terminate to return always
    #------------------------------------------------------------
    Log-Print "Checking for '$2' at '$1'..."

    if [[ ! -x "$1" ]]; then
        # not available or executable
        if [[ "$3" = "--no-terminate" ]]; then
            # return error
            return 1
        else
            # exit script with error
            Exit-WithError "Could not find '$2' at '$1'!"
        fi
    fi
    
    return 0
}


function Set-CustomProp {
    #------------------------------------------------------------
    # Set the value of a McAfee custom property
    #------------------------------------------------------------
    # Params: $1 = number of property to set (1-8) 
    #         $2 = value to set property
    #------------------------------------------------------------
    Log-Print "Setting EPO Custom Property #$1 to '$2'..."
    Log-Print ">> cmd = '$MACONFIG_PATH -custom -prop$1 \"$2\"'"

    # execute command and capture output to array
    IFS=$'\n'
    read -r -a OUT < <($MACONFIG_PATH -custom "-prop$1" "$2")
    ERR=$?
    unset IFS

    echo "length = '${#OUT[*]}'"

    for output in ${OUT[*]}; do
        # append output to log
        Log-Print ">> $output"
    done

    if [ $ERR -ne 0 ]; then
        # error encountered, exit script
        Exit-WithError "Error setting EPO Custom Property #$1 to '$2'!"
    fi
    
    return 0
}


function Get-CurrentDATVersion {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    local UVSCAN_DAT LOCAL_DAT_VERSION LOCAL_ENG_VERSION OUTPUT
    
    # get text of VSCL --version output
    if ! UVSCAN_DAT=$("$UVSCAN_DIR/$UVSCAN_EXE" --version); then
        # error getting version, exit script
        return 1
    fi

    # parse DAT version
    LOCAL_DAT_VERSION=$(printf "%s" "$UVSCAN_DAT" | grep -i "dat set version:" | cut -d' ' -f4)
    
    # parse engine version
    LOCAL_ENG_VERSION=$(printf "%s" "$UVSCAN_DAT" | grep -i "av engine version:" | cut -d' ' -f4)
    
    # return string STDOUT
    OUTPUT=$(printf "%s.0 (%s)" "$LOCAL_DAT_VERSION" "$LOCAL_ENG_VERSION")
    printf "%s" "$OUTPUT"

    return 0
}



function Download-File {
    #------------------------------------------------------------
    # Function to download a specified file from EPO repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #------------------------------------------------------------

    local FILE_NAME DOWNLOAD_URL FETCHER_CMD FETCHER

    # get the available HTTP download tool, preference to "wget", but "curl" is ok
    if command -v wget 2> /dev/null; then
        FETCHER="wget"
    elif command -v curl 2> /dev/null; then
        FETCHER="curl"
    else
        # no HTTP download tool available, exit script
        Exit-WithError "No valid URL fetcher available!"
    fi

    # type must be "bin" or "ascii"
    if [[ "$3" != "bin" ]] && [[ "$3" != "ascii" ]]; then
        Exit-WithError "Download type must be 'bin' or 'ascii'!"
    fi

    FILE_NAME="$4/$2"
    DOWNLOAD_URL="$1/$2"

    # download with available download tool
    case $FETCHER in
        "wget") FETCHER_CMD="wget -q --tries=10 --no-check-certificate ""$DOWNLOAD_URL"" -O ""$FILE_NAME"""
            ;;
        "curl") FETCHER_CMD="curl -s -k ""$DOWNLOAD_URL"" -o ""$FILE_NAME"""
            ;;
        *) Exit-WithError "No valid URL fetcher available!"
            ;;
    esac

    
    #FETCH_RESULT="$?"

    if ! $FETCHER_CMD; then
        return 1
    else
        # file downloaded OK
        if [[ "$3" = "ascii" ]]; then
            # strip any CR/LF line terminators
            tr -d '\r' < "$FILE_NAME" > "$FILE_NAME.tmp"
            rm -f "$FILE_NAME"
            mv "$FILE_NAME.tmp" "$FILE_NAME"
        fi
    fi
    
    return 0
}


function Validate-File {
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

#-----------------------------------------
# VSCL Library initialization code
#-----------------------------------------

# TEMP_DIR must be a directory and writable
TEMP_DIR=$(mktemp -d -p "$SCRIPT_PATH" 2> /dev/null)

if [[ -w "$TEMP_DIR" ]]; then
    Log-Print "Temporary directory created at '$TEMP_DIR'"
else
    Exit-WithError "Unable to create temporary directory '$TEMP_DIR'"
fi
