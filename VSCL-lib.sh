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

# Bypass inclusion if already loaded
if [[ -z "$_VSCL_LIB_LOADED" ]]; then
    _VSCL_LIB_LOADED=1
else
    exit 0
fi

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

function Do_Cleanup {
    #------------------------------------------------------------
    # if 'LEAVE_FILES' global is NOT set, erase downloaded files
    #------------------------------------------------------------

    if [[ -z "$LEAVE_FILES" ]]; then
        if [[ -d "$TEMP_DIR" ]]; then
            Log_Print "Removing temporary directory '$TEMP_DIR'..."
            
            if ! rm -rf "$TEMP_DIR"; then
                Log_Print "Error Removing temporary directory '$TEMP_DIR'!"
            fi
        fi
    else
        Log_Print "'LEAVE FILES' option specified.  NOT deleting temporary directory '$TEMP_DIR'"
    fi
    
    unset SCRIPT_NAME SCRIPT_PATH DEBUG_IT LEAVE_FILES LOG_PATH UVSCAN_EXE UVSCAN_DIR MACONFIG_PATH CMDAGENT_PATH TEMP_DIR _VSCL_LIB_LOADED
    return 0
}

function Exit_Script {
    #------------------------------------------------------------
    # Exit the script with an exit code
    #----------------------------------------------------------
    # Params: $1 = exit code (assumes 0/ok)
    #----------------------------------------------------------

    local OUTCODE

    Log_Print "==========================="

    if [[ -z "$1" ]]; then
        OUTCODE="0"
    else
        if [ "$1" != "0" ]; then
            OUTCODE="$1"
        fi
    fi
    
    Log_Print "Ending with exit code: $1"
    Log_Print "==========================="
    #Log_Print $SCRIPT_NAME
    #Log_Print $SCRIPT_PATH
    #Log_Print $SCRIPT_ABBR

    # Clean up temp files
    Do_Cleanup

    # shellcheck disable=SC2086
    exit $OUTCODE
}

function Exit_WithError {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
    # Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [[ -n "$1" ]]; then
        Log_Print "$1"
    fi

    Do_Cleanup
    Exit_Script 1
}

function Log_Print {
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

function Capture_Command {
    #------------------------------------------------------------
    # Function to capture output of command to log
    #------------------------------------------------------------
    # Params: $1 = command to capture
    #         $2 = arguments of command
    #----------------------------------------------------------
    local OUT ERR OUTPUT MASK CAPTURECMD CAPTUREARG SAVEIFS
    
    if [[ -z "$1" ]]; then
        Exit_WithError "Command to capture empty!"
    else
        CAPTURECMD="$1"
    fi

    if [[ -z "$2" ]]; then
        Exit_WithError "Arguments of command to capture empty!"
    else
        CAPTUREARG="$2"
    fi
    
    Log_Print ">> cmd = '$1 $2'"
    
    MASK="s/^[[:digit:]][[:digit:]][[:digit:]][[:digit:]]-[[:digit:]][[:digit:]]-[[:digit:]][[:digit:]] [[:digit:]][[:digit:]]:[[:digit:]][[:digit:]]:[[:digit:]][[:digit:]]\.[[:digit:]]* ([[:digit:]]*\.[[:digit:]]*) //g"
    
    SAVEIFS=$IFS
    # run command and capture output
    IFS=$'\n' OUT=($(eval $CAPTURECMD $CAPTUREARG))
    ERR=$?
    IFS=$SAVEIFS

    for OUTPUT in "${OUT[@]}"; do
        # append output to log
        if [[ -n "$MASK" ]]; then
            # mask supplied, apply to each line
            OUTPUT=$(echo $OUTPUT | sed -e "$MASK")
        fi
        
        Log_Print ">> $OUTPUT"
    done
    
    if [ $ERR -ne 0 ]; then
        # error, exit sctipt
        Exit_WithError "Error running command '$CAPTURECMD $CAPTUREARG'"
    fi
    
    return 0
}


function Refresh_ToEPO {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------

    # flags to use with CMDAGENT utility
    local CMDAGENTFLAGS MASK FLAGNAME
    CMDAGENTFLAGS="-c -f -p -e"
    Log_Print "Refreshing agent data with EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAGNAME in $CMDAGENTFLAGS; do
        Capture_Command "$CMDAGENT_PATH" "$FLAGNAME"
        # unset OUT
        # Log_Print ">> cmd = '$CMDAGENT_PATH $FLAG_NAME'"
        
        # # run command and capture output
        # unset OUT
        # SAVE_IFS=$IFS
        # IFS=$'\n' OUT=($($CMDAGENT_PATH "$FLAG_NAME"))
        # ERR=$?

        # for output in "${OUT[@]}"; do
            # # append output to log
            # Log_Print ">> $output"
        # done

        # IFS=$SAVE_IFS
        
        # if [ $ERR -ne 0 ]; then
            # # error, exit sctipt
            # Exit_WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'\!"
        # fi
    done
    
    return 0
}


function Find_INISection {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Output: space-delimited INI entries
    #----------------------------------------------------------

    local SECTION_FOUND SECTION_NAME LINE

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


function Check_For {
    #------------------------------------------------------------
    # Function to check that a file is available and executable
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) --no-terminate to return always
    #------------------------------------------------------------
    Log_Print "Checking for '$2' at '$1'..."

    if [[ ! -x "$1" ]]; then
        # not available or executable
        if [[ "$3" = "--no-terminate" ]]; then
            # return error
            return 1
        else
            # exit script with error
            Exit_WithError "Could not find '$2' at '$1'!"
        fi
    fi
    
    return 0
}


function Set_CustomProp {
    #------------------------------------------------------------
    # Set the value of a McAfee custom property
    #------------------------------------------------------------
    # Params: $1 = number of property to set (1-8) 
    #         $2 = value to set property
    #------------------------------------------------------------
    Log_Print "Setting EPO Custom Property #$1 to '$2'..."
    Capture_Command "$MACONFIG_PATH" "-custom -prop$1 '$2'"
    # Log_Print ">> cmd = '$MACONFIG_PATH -custom -prop$1 \"$2\"'"

    # # execute command and capture output to array
    # unset OUT
    # IFS=$'\n' OUT=($($MACONFIG_PATH -custom "-prop$1" "$2"))
    # ERR=$?

    # for output in "${OUT[@]}"; do
        # # append output to log
        # Log_Print ">> $output"
    # done

    # unset IFS

    # if [ $ERR -ne 0 ]; then
        # # error encountered, exit script
        # Exit_WithError "Error setting EPO Custom Property #$1 to '$2'!"
    # fi
    
    return 0
}


function Get_CurrentDATVersion {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------
    # Params: $1 = which part to return
    #              <blank>: Entire DAT and engine string (default)
    #              DATMAJ:  DAT file major version #
    #              DATMIN:  DAT file minor version # (always zero)
    #              ENGMAJ:  Engine major version #
    #              ENGMIN:  Engine minor version #
    #------------------------------------------------------------
    # Output: null if error, otherwise number according to
    #         value of $1 (see above), default entire DAT and 
    #         engine string
    #----------------------------------------------------------

    local UVSCAN_DAT LOCAL_DAT_VERSION LOCAL_ENG_VERSION OUTPUT

    Check_For "$UVSCAN_DIR/$UVSCAN_EXE" "uvscan executable" > /dev/null 2>&1
    
    # get text of VSCL --version output
    if ! UVSCAN_DAT=$("$UVSCAN_DIR/$UVSCAN_EXE" --version 2> /dev/null); then
        # error getting version, exit script (returns null output)
        return 1
    fi

    # parse DAT version
    LOCAL_DAT_VERSION=$(printf "%s\n" "$UVSCAN_DAT" | grep -i "dat set version:" | cut -d' ' -f4)
    
    # parse engine version
    LOCAL_ENG_VERSION=$(printf "%s\n" "$UVSCAN_DAT" | grep -i "av engine version:" | cut -d' ' -f4)
    
    # default to printing entire DAT and engine string, i.e. "9999.0 (9999.9999)"
    OUTPUT=$(printf "%s.0 (%s)\n" "$LOCAL_DAT_VERSION" "$LOCAL_ENG_VERSION")

    if [[ ! -z $1 ]]; then
        case $1 in
            # Extract everything up to first '.'
            "DATMAJ") OUTPUT="$(echo "$LOCAL_DAT_VERSION" | cut -d. -f-1)"
                ;; 
            # Always retruns zero
            "DATMIN") OUTPUT="0"
                ;;
            # Extract everything up to first '.'
            "ENGMAJ") OUTPUT="$(echo "$LOCAL_ENG_VERSION" | cut -d. -f-1)"
                ;;
            # Extract everything after first '.'
            "ENGMIN") OUTPUT="$(echo "$LOCAL_ENG_VERSION" | cut -d' ' -f1 | cut -d. -f2-)"
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    fi
    
    # return string STDOUT
    printf "%s\n" "$OUTPUT"

    return 0
}

function Download_File {
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
    if command -v wget > /dev/null 2>&1; then
        FETCHER="wget"
    elif command -v curl > /dev/null 2>&1; then
        FETCHER="curl"
    else
        # no HTTP download tool available, exit script
        Exit_WithError "No valid URL fetcher available!"
    fi

    # type must be "bin" or "ascii"
    if [[ "$3" != "bin" ]] && [[ "$3" != "ascii" ]]; then
        Exit_WithError "Download type must be 'bin' or 'ascii'!"
    fi

    FILE_NAME="$4/$2"
    DOWNLOAD_URL="$1/$2"

    # download with available download tool
    case $FETCHER in
        "wget") FETCHER_CMD="wget -q --tries=10 --no-check-certificate ""$DOWNLOAD_URL"" -O ""$FILE_NAME"""
            ;;
        "curl") FETCHER_CMD="curl -s -k ""$DOWNLOAD_URL"" -o ""$FILE_NAME"""
            ;;
        *) Exit_WithError "No valid URL fetcher available!"
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


function Validate_File {
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
        Log_Print "File '$1' size is correct ($2)"
    else
        Exit_WithError "Downloaded DAT size '$SIZE' should be '$1'!"
    fi

    # make MD5 check optional. return "success" if there's no support
    if [[ -z "$MD5CHECKER" ]] || [[ ! -x $(command -v $MD5CHECKER 2> /dev/null) ]]; then
        Log_Print "MD5 Checker not available, skipping MD5 check..."
        return 0
    fi

    # Check the MD5 checksum...
    MD5_CSUM=$($MD5CHECKER "$1" 2>/dev/null | cut -d' ' -f1)

    if [[ -n "$MD5_CSUM" ]] && [[ "$MD5_CSUM" = "$3" ]]; then
        Log_Print "File '$1' MD5 checksum is correct ($3)"
    else
        Exit_WithError "Downloaded DAT MD5 hash '$MD5_CSUM' should be '$3'!"
    fi

    return 0
}

#-----------------------------------------
# VSCL Library initialization code
#-----------------------------------------

# TEMP_DIR must be a directory and writable
TEMP_DIR=$(mktemp -d -p "$SCRIPT_PATH" 2> /dev/null)

if [[ -w "$TEMP_DIR" ]]; then
    Log_Print "Temporary directory created at '$TEMP_DIR'"
else
    Exit_WithError "Unable to create temporary directory '$TEMP_DIR'"
fi
