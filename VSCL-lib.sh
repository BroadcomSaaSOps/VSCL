#!/bin/bash

#=============================================================================
# NAME:         VSCL-lib.sh
#-----------------------------------------------------------------------------
# Purpose:      Shared code for VSCL management scripts
#-----------------------------------------------------------------------------
# Creator:      Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:         03-FEB-2020
#-----------------------------------------------------------------------------
# Version:      1.2
#-----------------------------------------------------------------------------
# PreReqs:      none
#-----------------------------------------------------------------------------  
# Switches:     -f: force library to load even if already loaded
#-----------------------------------------------------------------------------  
# Imports:      ./VSCL-local.sh:    local per-site variables
#=============================================================================


#=============================================================================
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
# If this file is NOT sourced, return error
echo a
if ! $(return 0 2>/dev/null); then
    echo b
    echo ">> ERROR! VSCL Library must be sourced.  It cannot be run standalone!"
    echo c
    exit 1
fi

echo d
# Bypass inclusion if already loaded
if [[ -z "$__VSCL_LIB_LOADED" ]]; then
    # not already loaded, set flag that it is now
    #echo "not loaded, loading..."
    __VSCL_LIB_LOADED=1
else
    # already loaded, exit gracefully
    #echo "loaded already"
    return 0
fi


#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
#echo "VSCL_EPOInstall called"
. ./VSCL-local.sh


#=============================================================================
# GLOBALS: Global variables used by all scripts that import this library
#=============================================================================
unset __VSCL_SCRIPT_ABBR __VSCL_SCRIPT_NAME __VSCL_SCRIPT_PATH __VSCL_DEBUG_IT
unset __VSCL_LEAVE_FILES __VSCL_LOG_PATH __VSCL_UVSCAN_EXE __VSCL_UNINSTALL_EXE 
unset __VSCL_UVSCAN_DIR __VSCL_UVSCAN_CMD __VSCL_INSTALL_CMD __VSCL_UNINSTALL_CMD 
unset __VSCL_WRAPPER __VSCL_LIBRARY __VSCL_LOCALIZATION __VSCL_MACONFIG_PATH 
unset __VSCL_CMDAGENT_PATH __VSCL_INSTALL_PKG __VSCL_INSTALL_VER __VSCL_PKG_VER_FILE 
unset __VSCL_PKG_VER_SECTION __VSCL_EPO_VER_FILE __VSCL_EPO_VER_SECTION 
unset __VSCL_EPO_FILE_LIST __VSCL_TOOLBOX_FILES __VSCL_MASK_REGEXP 
unset __VSCL_NOTINST_CODE __VSCL_INVALID_CODE 

# name of script file (the one that dotsourced this library, not the library itself)
# shellcheck disable=SC2034
__VSCL_SCRIPT_NAME=$(basename "${BASH_SOURCE%/*}/")

# path to script file (the one that dotsourced this library, not the library itself)
__VSCL_SCRIPT_PATH=$(dirname "${BASH_SOURCE%/*}/")

# show debug messages (set to non-empty to enable)
#__VSCL_DEBUG_IT=

# flag to erase any temp files on exit (set to non-empty to enable)
#__VSCL_LEAVE_FILES=

# Path to common log file for all VSCL scripts
__VSCL_LOG_PATH="/var/McAfee/agent/logs/VSCL_mgmt.log"

# name of VSCL scanner executable
__VSCL_UVSCAN_EXE="uvscan"

# name of VSCL scanner uninstaller
__VSCL_UNINSTALL_EXE="uninstall-uvscan"

# __VSCL_UVSCAN_DIR must be a directory and writable where VSCL is installed
__VSCL_UVSCAN_DIR="/usr/local/uvscan"

# full path to uvscan executable
__VSCL_UVSCAN_CMD="$__VSCL_UVSCAN_DIR/$__VSCL_UVSCAN_EXE"

# Raw command to install VSCL from installer tarball
# shellcheck disable=SC2034
__VSCL_INSTALL_CMD="install-uvscan"

# Raw command to remove VSCL from system
# shellcheck disable=SC2034
__VSCL_UNINSTALL_CMD="$__VSCL_UVSCAN_DIR/$__VSCL_UNINSTALL_EXE"

# Filename of scan wrapper to copy to VSCL software directory
__VSCL_WRAPPER="uvwrap.sh"

# Filename of VSCL library to copy to VSCL software directory (i.e. this file)
__VSCL_LIBRARY="VSCL-lib.sh"

# Filename for site localization
__VSCL_LOCALIZATION="VSCL-local.sh"

# path to MACONFIG program
__VSCL_MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
__VSCL_CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

# EPO package name of uploaded VSCL installer
# shellcheck disable=SC2034
__VSCL_INSTALL_PKG="VSCLPACK"

# Version of EPO package name of uploaded VSCL installer
# shellcheck disable=SC2034
__VSCL_INSTALL_VER="6130"

# Name of versioning file in EPO installer package
# shellcheck disable=SC2034
__VSCL_PKG_VER_FILE="vsclpackage.ini"

# Section name of versioning file to search for
# shellcheck disable=SC2034
__VSCL_PKG_VER_SECTION="VSCL-PACK"

# name of the repo file with current DAT version
# shellcheck disable=SC2034
__VSCL_EPO_VER_FILE="avvdat.ini"

# section of avvdat.ini from repository to examine for DAT version
# shellcheck disable=SC2034
__VSCL_EPO_VER_SECTION="AVV-ZIP"

# space-delimited list of files to unzip from downloaded EPO .ZIP file
# format => <filename>:<permissions>
# shellcheck disable=SC2034
__VSCL_EPO_FILE_LIST="avvscan.dat:444 avvnames.dat:444 avvclean.dat:444"

# space-delimited list of files to unzip from downloaded EPO .ZIP file
# format => <filename>:<permissions>
# shellcheck disable=SC2034
__VSCL_TOOLBOX_FILES="./$__VSCL_WRAPPER:+x ./$__VSCL_LIBRARY:+x ./$__VSCL_LOCALIZATION:+x "

# sed style mask to remove common text in McAfee error messages
# example "2020-01-25 14:22:44.456234 (2010.2739) maconfig.Info: configuration finished"
# will be logged as  ">> maconfig.Info: configuration finished"
__VSCL_MASK_REGEXP="s/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*\ ([0-9]*\.[0-9]*)\ //g"

# default return codes for Custom 1 property fields
# shellcheck disable=SC2034
__VSCL_NOTINST_CODE="VSCL:NOT_INSTALLED"
__VSCL_INVALID_CODE="VSCL:INVALID_DAT"


#=============================================================================
# FUNCTIONS: VSCL Library functions
#=============================================================================

function Do_Cleanup {
    #------------------------------------------------------------
    # If '__VSCL_LEAVE_FILES' global is NOT set, erase downloaded files
    # before exiting
    #------------------------------------------------------------

    if [[ -z "$__VSCL_LEAVE_FILES" ]]; then
        if [[ -d "$__VSCL_TEMP_DIR" ]]; then
            # Log_Info "Removing temp dir '$__VSCL_TEMP_DIR'..."
            
            if ! rm -rf "$__VSCL_TEMP_DIR"; then
                Log_Warning "Cannot remove temp dir '$__VSCL_TEMP_DIR'!"
            fi

            # Log_Info "Removing temp file '$__VSCL_TEMP_FILE'..."
            
            if ! rm -rf "$__VSCL_TEMP_FILE"; then
                Log_Warning "Cannot remove temp file '$__VSCL_TEMP_FILE'!"
            fi
        fi
    else
        Log_Info "'LEAVE FILES' option specified.  NOT deleting temp dir '$__VSCL_TEMP_DIR' or file '$__VSCL_TEMP_FILE'!"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function Exit_Script {
    #------------------------------------------------------------
    # Exit the script with an exit code
    #----------------------------------------------------------
    # Params: $1 = exit code (assumes 0/ok)
    #----------------------------------------------------------

    local OUTCODE

    Log_Info "==========================="

    if [[ -z "$1" ]]; then
        OUTCODE="0"
    else
        if [ "$1" != "0" ]; then
            OUTCODE="$1"
        fi
    fi
    
    Log_Info "Ending with exit code: $1"
    Log_Info "==========================="

    # Clean up temp files
    Do_Cleanup

    case "$-" in
        # do a simple RETURN if invoked from the command line
        *i*) return $OUTCODE
            ;;
        # otherwise exit the script
        *) exit  $OUTCODE
            ;;
    esac
}

#-----------------------------------------------------------------------------

function Exit_WithError {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
    # Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [[ -n "$1" ]]; then
        Log_Error "$1"
    fi

    Exit_Script 1
}

#-----------------------------------------------------------------------------

function Log_Print {
    #----------------------------------------------------------
    # Print a message to the log defined in $__VSCL_LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    local OUTTEXT SAVE_OPTS
    
    SAVE_OPTS=$SHELLOPTS
    set +x
    
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
    
    if [[ "$SAVE_OPTS" == *"xtrace"* ]]; then
        set -x
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function Log_Info {
    #----------------------------------------------------------
    # Print a INFO MESSAGE to the log defined in $__VSCL_LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = info message to print
    #----------------------------------------------------------

    # Prepend info marker and print
    Log_Print "[I]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function Log_Warning {
    #----------------------------------------------------------
    # Print a WARNING to the log defined in $__VSCL_LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = warning message to print
    #----------------------------------------------------------

    # Prepend warning marker and print
    Log_Print "[W]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function Log_Error {
    #----------------------------------------------------------
    # Print an ERROR to the log defined in $__VSCL_LOG_PATH
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    # Prepend error marker and print
    Log_Print "[E]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function Capture_Command {
    #------------------------------------------------------------
    # Function to capture output of command to log
    #------------------------------------------------------------
    # Params: $1 = command to capture
    #         $2 = arguments of command
    #         $3 = command to run and pipe into captured command
    #------------------------------------------------------------
    # Returns: 0/ok if command ran
    #          Error code if command failed
    #------------------------------------------------------------
    local ERR OUTTEXT CAPTURE_CMD CAPTURE_ARG VAR_EMPTY PRE_CMD
    
    VAR_EMPTY=""
    CAPTURE_CMD="${1:-$VAR_EMPTY}"
    CAPTURE_ARG="${2:-$VAR_EMPTY}"
    PRE_CMD="${3:-$VAR_EMPTY}"

    if [[ -z "$CAPTURE_CMD" ]]; then
        Exit_WithError "Command to capture empty!"
    fi

    if [[ -n "$PRE_CMD" ]]; then
        Log_Info ">> cmd = '$PRE_CMD | $CAPTURE_CMD $CAPTURE_ARG'"
    else
        Log_Info ">> cmd = '$CAPTURE_CMD $CAPTURE_ARG'"
    fi
    
    # shellcheck disable=SC2086
    if [[ -n "$PRE_CMD" ]]; then
        $PRE_CMD | $CAPTURE_CMD $CAPTURE_ARG > "$__VSCL_TEMP_FILE" 2>&1
    else
        $CAPTURE_CMD $CAPTURE_ARG > "$__VSCL_TEMP_FILE" 2>&1
    fi
    
    ERR=$?
    IFS=$__VSCL_SAVE_IFS
    OUTARRAY=()
    
    IFS=$'\n' read -r -d '' -a OUTARRAY < <( cat "$__VSCL_TEMP_FILE" && printf '\0' )
    # while read -r line; do
        # OUTARRAY+=( "$line" )
    # done < <( echo "${OUT[*]}" )

    for OUTTEXT in "${OUTARRAY[@]}"; do
        # loop through each line of OUTTEXT
        # append OUTTEXT to log
        if [[ -n "$__VSCL_MASK_REGEXP" ]]; then
            # mask supplied, apply to each line
            OUTTEXT=$(printf "%s\n" "$OUTTEXT" | sed -e "$__VSCL_MASK_REGEXP")
        fi
        
        Log_Info ">> $OUTTEXT"
    done

    
    
    if [ $ERR -ne 0 ]; then
        # error running command, return error code
        #Exit_WithError "Error running command '$CAPTURE_CMD ${CAPTURE_ARG[@]} $REDIRECT_CMD'"
        return $ERR
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function Refresh_ToEPO {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------
    local CMDAGENT_FLAGS FLAG_NAME

    # flags to use with CMDAGENT utility
    CMDAGENT_FLAGS="-c -f -p -e"
    Log_Info "Refreshing agent data to EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAG_NAME in $CMDAGENT_FLAGS; do
        if ! Capture_Command "$__VSCL_CMDAGENT_PATH" "$FLAG_NAME"; then
            Log_Error "Error running EPO refresh command '$__VSCL_CMDAGENT_PATH $FLAG_NAME'\!"
        fi
    done
    
    return 0
}

#-----------------------------------------------------------------------------

function Find_INISection {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Returns: space-delimited INI entries in specified 
    #          section to to STDOUT
    #          exit code = 0 if section found
    #          exit code = 1 if section NOT found
    #----------------------------------------------------------

    local IN_SECTION SECTION_FOUND SECTION_NAME LINE

    SECTION_NAME="[$1]"
    #echo "\$SECTION_NAME = '$SECTION_NAME'" 2>&1

    # Read each line of the file
    while read -rs LINE; do
        #echo "\$LINE = '$LINE'" 2>&1
        if [[ "$LINE" = "$SECTION_NAME" ]]; then
            # Section header found, go to next line
            SECTION_FOUND=1
            IN_SECTION=1
        elif [[ -n "$IN_SECTION" ]]; then
            # In correct section
            if [[ "$(echo "$LINE" | cut -c1)" != "[" ]]; then
                # not a section header
                if [[ -n "$LINE" ]]; then
                    # line not empty, append to STDOUT
                    printf "%s\n" "$LINE"
                fi
            else
                # reached next section
                unset IN_SECTION
            fi
        fi
    done
    
    if [[ -n "$SECTION_FOUND" ]]; then
        return 0
    else
        Log_Error "Section '$1' not found"
        return 1
    fi
}

#-----------------------------------------------------------------------------

function Check_For {
    #------------------------------------------------------------
    # Function to check that a file is available and executable
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) "--no-terminate" to return always
    #------------------------------------------------------------
    Log_Info "Checking for '$2' at '$1'..."

    if [[ ! -x "$1" ]]; then
        # not available or executable
        if [[ "$3" = "--no-terminate" ]]; then
            # return error but do not exit script
            Log_Error "Could not find file '$2' at '$1'!"
            return 1
        else
            # exit script with error
            Exit_WithError "Could not find file '$2' at '$1'!"
        fi
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function Set_CustomProp {
    #------------------------------------------------------------
    # Set the value of a McAfee custom property
    #------------------------------------------------------------
    # Params: $1 = number of property to set (1-8) 
    #         $2 = value to set property
    #------------------------------------------------------------
    local ERR NEW_LABEL MA_OPTIONS
    
    NEW_LABEL="${2/ /_}"
    
    MA_OPTIONS=("-custom"  "-prop$1" "$NEW_LABEL")
    
    Log_Info "Setting EPO Custom Property #$1 to '$2'..."
    
    if ! Capture_Command "$__VSCL_MACONFIG_PATH" "${MA_OPTIONS[*]}"; then
        return 1
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function Get_CurrDATVer {
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

    local UVSCAN_STATUS LOCAL_DAT_VER LOCAL_ENG_VER OUTTEXT RESULT 
    #echo "c"
    #ls -lAh $LOCAL_VER_FILE

    if ! Check_For "$__VSCL_UVSCAN_CMD" "uvscan executable" > /dev/null 2>&1 ; then
        printf "%s\n" "$__VSCL_INVALID_CODE"
        return 1
    fi
    #echo "d"
    #ls -lAh $LOCAL_VER_FILE
    
    RESULT=$("$__VSCL_UVSCAN_CMD" --VERSION 2> /dev/null)
    
    #echo "e"
    #ls -lAh $LOCAL_VER_FILE

    # shellcheck disable=SC2181
    if [[ "$?" == "0" ]]; then
        UVSCAN_STATUS=$RESULT
    else
        printf "%s\n" "$__VSCL_INVALID_CODE"
        return 1
    fi
        
    # parse DAT version
    LOCAL_DAT_VER=$(printf "%s\n" "$UVSCAN_STATUS" | grep -i "dat set version:" | cut -d' ' -f4)
    
    # parse engine version
    LOCAL_ENG_VER=$(printf "%s\n" "$UVSCAN_STATUS" | grep -i "av engine version:" | cut -d' ' -f4)
    
    # default to printing entire DAT and engine string, i.e. "9999.0 (9999.9999)"
    OUTTEXT=$(printf "%s.0 (%s)\n" "$LOCAL_DAT_VER" "$LOCAL_ENG_VER")

    if [[ -n $1 ]]; then
        case $1 in
            # Extract everything up to first '.'
            "DATMAJ") OUTTEXT="$(echo "$LOCAL_DAT_VER" | cut -d. -f-1)"
                ;; 
            # Always retruns zero
            "DATMIN") OUTTEXT="0"
                ;;
            # Extract everything up to first '.'
            "ENGMAJ") OUTTEXT="$(echo "$LOCAL_ENG_VER" | cut -d. -f-1)"
                ;;
            # Extract everything after first '.'
            "ENGMIN") OUTTEXT="$(echo "$LOCAL_ENG_VER" | cut -d' ' -f1 | cut -d. -f2-)"
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    fi
    
    # return string STDOUT
    printf "%s\n" "$OUTTEXT"

    return 0
}

#-----------------------------------------------------------------------------

function Download_File {
    #------------------------------------------------------------
    # Function to download a specified file from EPO repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #------------------------------------------------------------

    local FILE_NAME DOWNLOAD_URL FETCHER FETCHER_CMD FETCHER_ARG

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
        "wget") FETCHER_CMD="wget"
                FETCHER_ARG="--quiet --tries=10 --no-check-certificate --output-document=""$FILE_NAME"" $DOWNLOAD_URL"
            ;;
        "curl") FETCHER_CMD="curl"
                FETCHER_ARG="-s -k ""$DOWNLOAD_URL"" -o ""$FILE_NAME"""
            ;;
        *) Exit_WithError "No valid URL fetcher available!"
            ;;
    esac

    
    #FETCH_RESULT="$?"

    if Capture_Command "$FETCHER_CMD" "$FETCHER_ARG"; then
        # file downloaded OK
        if [[ "$3" = "ascii" ]]; then
            # strip any CR/LF line terminators
            #echo "\$FILE_NAME = '$FILE_NAME'"
            #ls -lAh $FILE_NAME
            #file $FILE_NAME
            tr -d '\r' < "$FILE_NAME" > "$FILE_NAME.tmp"
            #ls -lAh "$FILE_NAME.tmp"
            #file "$FILE_NAME.tmp"
            rm -f "$FILE_NAME"
            mv "$FILE_NAME.tmp" "$FILE_NAME"
        fi
        #Log_Info "ok"
    else
        Exit_WithError "Unable to download '$DOWNLOAD_URL' to '$FILE_NAME'!"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

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
        Log_Info "File '$1' size is correct ($2)"
    else
        Exit_WithError "Downloaded DAT size '$SIZE' should be '$1'!"
    fi

    # make MD5 check optional. return "success" if there's no support
    if [[ -z "$MD5CHECKER" ]] || [[ ! -x $(command -v $MD5CHECKER 2> /dev/null) ]]; then
        Log_Warning "MD5 Checker not available, skipping MD5 check..."
        return 0
    fi

    # Check the MD5 checksum...
    MD5_CSUM=$($MD5CHECKER "$1" 2>/dev/null | cut -d' ' -f1)

    if [[ -n "$MD5_CSUM" ]] && [[ "$MD5_CSUM" = "$3" ]]; then
        Log_Info "File '$1' MD5 checksum is correct ($3)"
    else
        Exit_WithError "Downloaded DAT MD5 hash '$MD5_CSUM' should be '$3'!"
    fi

    return 0
}

#-----------------------------------------------------------------------------

function Copy_Files_With_Modes {
    #--------------------------------------------------------------------
    # Function to copy one file from source to destination
    #--------------------------------------------------------------------
    # Params: $1 - List of files to copy
    #              (format => <filepath>:<chmod>, relative path OK)
    #         $2 - Destination directory (including path, relative OK)
    #--------------------------------------------------------------------
    local FILES_TO_COPY FNAME_MODES FILE_NAME FILE_MODE

    # echo "\$1 = '$1'"
    # echo "\$2 = '$2'"

    if [[ ! -d $2 ]]; then
        Exit_WithError "'$2' is not a directory!"
    fi

    # strip filename to a list
    for FNAME_MODES in $1; do
        # echo "\$FNAME_MODES = '$FNAME_MODES'"
        FILE_NAME=$(printf "%s\n" "$FNAME_MODES" | awk -F':' ' { print $1 } ')
        FILES_TO_COPY="$FILES_TO_COPY $FILE_NAME"
        echo "\$FILES_TO_COPY = '$FILES_TO_COPY'"
    done

    if ! Capture_Command "\\cp" "$FILES_TO_COPY $2"; then
        Exit_WithError "Error copying '$FILES_TO_COPY' to '$2'!"
    fi

    # apply chmod permissions from list
    for FNAME_MODES in $1; do
        FILE_NAME=$(printf "%s\n" "$FNAME_MODES" | awk -F':' ' { print $1 } ')
        FILE_MODE=$(printf "%s\n" "$FNAME_MODES" | awk -F':' ' { print $NF } ')
        
        if ! Capture_Command "chmod" "$FILE_MODE $2/${FILE_NAME##*/}"; then
            Exit_WithError "Error setting mode '$FILE_MODE' on '$2/${FILE_NAME##*/}'!"
        fi
    done

    return 0
}

#-----------------------------------------------------------------------------

function Update_FromZip {
    #---------------------------------------------------------------
    # Function to extract the listed files from the given zip file.
    #---------------------------------------------------------------
    # Params: $1 - Directory to unzip to
    #         $2 - Downloaded zip file
    #         $3 - List of files to unzip
    #              (format => <filename>:<chmod>)
    #---------------------------------------------------------------

    local FILES_TO_DOWNLOAD FNAME FILE_NAME UNZIPOPTIONS PERMISSIONS

    # strip filename to a list
    for FNAME in $3; do
        FILE_NAME=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $1 } ')
        FILES_TO_DOWNLOAD="$FILES_TO_DOWNLOAD $FILE_NAME"
    done

    # BACKUP_DIR="./backup"

    #Backup any files about to be updated...
    # if [[ ! -d "$BACKUP_DIR" ]]; then
        # Log_Info "Creating backup directory files to be updated..."
        # mkdir -d -p "$BACKUP_DIR" 2> /dev/null
    # fi

    # if [[ -d "$BACKUP_DIR" ]]; then
        # cp "$FILES_TO_DOWNLOAD" "backup" 2>/dev/null
    # fi

    # Update the DAT files.
    Log_Info "Uncompressing '$2' to '$1'..."
    UNZIPOPTIONS="-o -d $1 $2 $FILES_TO_DOWNLOAD"

    # shellcheck disable=SC2086
    if ! unzip $UNZIPOPTIONS 2> /dev/null; then
        Exit_WithError "Error unzipping '$2' to '$1'!"
    fi

    # apply chmod permissions from list
    for FNAME in $3; do
        FILE_NAME=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $1 } ')
        PERMISSIONS=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $NF } ')
        chmod "$PERMISSIONS" "$1/$FILE_NAME"
    done

    return 0
}

function Init_Library {
    #---------------------------------------------------------------
    # Initialize the library functions
    #---------------------------------------------------------------
    # Switches:     -f: force library to load even if already loaded
    #---------------------------------------------------------------

    # echo --------------------------------
    # set | grep -i bash
    # echo --------------------------------
    # echo "\$0 = '$0'"
    # echo --------------------------------

    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    unset OPTION_VAR

    while getopts :fu OPTION_VAR; do
        echo "\$OPTION_VAR = '$OPTION_VAR'"
        case "$OPTION_VAR" in
            # force library to load even if already loaded
            "f") #echo "force"
                 unset __VSCL_LIB_LOADED
                ;;
            #"u") #echo "unload"
            #     unset -f  $( set | grep -i '^__vscl.*\ ()' | awk '{print $1}' )
            #     unset $( set | grep -i '^__vscl.*=.*' | awk -F"=" '{print $1}' )
            #     return 0
            #    ;;
            *)   echo "Unknown option '$OPTION_VAR' specified!"
                 exit 1
                ;;
        esac
    done

    #shift "$((OPTIND-1))"

    # echo "\$__VSCL_LIB_LOADED = '$__VSCL_LIB_LOADED'"
    #-----------------------------------------
    # VSCL Library initialization code
    #-----------------------------------------
    #echo "\$__VSCL_TEMP_DIR = '$__VSCL_TEMP_DIR'"
    __VSCL_SCRIPT_ABBR="VSCLLIB"

    if [[ -z "$__VSCL_TEMP_DIR" ]]; then
        # no current temp directory specified in environment
        # __VSCL_TEMP_DIR must be a directory and writable
        __VSCL_TEMP_DIR=$(mktemp -d -p "$__VSCL_SCRIPT_PATH" 2> /dev/null)
    fi

    if [[ ! -d "$__VSCL_TEMP_DIR" ]]; then
        # Log_Info "Temporary directory: '$__VSCL_TEMP_DIR'"
    # else
        Exit_WithError "Unable to use temporary directory '$__VSCL_TEMP_DIR'"
    fi

    if [[ -z "$__VSCL_TEMP_FILE" ]]; then
        # no current temp file specified in environment
        # __VSCL_TEMP_FILE must be a file and writable
        __VSCL_TEMP_FILE=$(mktemp -p "$__VSCL_SCRIPT_PATH" 2> /dev/null)
    fi

    if [[ ! -f "$__VSCL_TEMP_FILE" ]]; then
        # Log_Info "Temporary file: '$__VSCL_TEMP_FILE'"
    # else
        Exit_WithError "Unable to use temporary file '$__VSCL_TEMP_FILE'"
    fi

    __VSCL_SAVE_IFS=$IFS
    return 0
}

#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is sourced, execute initialization and return to sourcing code
Init_Library "$@"
return $?
