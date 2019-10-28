#!/bin/bash
#
#=============================================================================
# NAME:         VSCL-Update-DAT.sh
# Purpose:      Update the DAT files for the McAfee VirusScan Command Line
#                       Scanner 6.1.3 on SaaS Linux PPM App servers from EPO
# Creator:      Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
# Original:     Copyright (c) 2009 McAfee, Inc. All Rights Reserved.
# Date:         21-OCT-2019
# Version:      1.2
# PreReqs:      Linux
#               CA PPM Application Server
#               VSCL antivirus scanner installed
#               Latest VSCL DAT .ZIP file
#               unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#               awk, echo, cut, ls, printf, wget
# Params:       none
# Switches:     -d:  download current DATs and exit
#               -l:  leave any files extracted intact at exit
# Imports:      ./VSCL-local.sh
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================

#  Imports
#-----------------------------------------
. ./VSCL-local.sh

# Defaults: Do not modify
#-----------------------------------------
unset MD5CHECKER LEAVE_FILES DEBUG_IT FETCHER SCRIPT_NAME SITE_NAME EPO_SERVER
unset PERFORM_UPDATE LOCAL_VERSION_FILE DAT_ZIP UVSCAN_EXE UVSCAN_SWITCHES
unset MACONFIG_PATH CMDAGENT_PATH UVSCAN_DIR TMP_DIR VER_SECTION DOWNLOAD_SITE
unset FILE_LIST DOWNLOAD_ONLY OPTION_VAR LOG_FILE

# Process command line options
#-----------------------------------------
while getopts :dl OPTION_VAR; do
    case "$OPTION_VAR" in
        "d") DOWNLOAD_ONLY=1    # only download most current DAT from EPO and exit
            ;;
        "l") LEAVE_FILES=1      # leave any temp files on exit
            ;;
        *) Exit-WithError "Unknown option specified!"
            ;;
    esac
done

# Globals
# (these variables are normally best left unmodified)
#-----------------------------------------
# name and path of this script
SCRIPT_NAME=$(basename "$0")
SCRIPT_PATH=$(dirname "$0")

# name of the repo file with current DAT version
VERSION_FILE="avvdat.ini"

# name of scanner executable
UVSCAN_EXE="uvscan"
UVSCAN_SWITCHES=""

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

# Change these variables to match your environment
# UVSCAN_DIR must be a directory and writable where uvscan is installed
UVSCAN_DIR="/usr/local/uvscan"

# TMP_DIR must be a directory and writable
TMP_DIR=$(mktemp -d -p "$SCRIPT_PATH" 2> /dev/null)

if [[ ! -d "$TMP_DIR" ]];then
    Exit-WithError "Unable to create temporary directory '$TMP_DIR'"
fi

# Name of the file in the repository to extract current DAT version from
LOCAL_VERSION_FILE="$TMP_DIR/$VERSION_FILE"

# section of avvdat.ini from repository to examine for DAT version
VER_SECTION="AVV-ZIP"

# Optional: Program for calculating the MD5 for a file
MD5CHECKER="md5sum"

# Program to use to download files from web repository
# (default is wget but curl is OK)
FETCHER="wget"

# Preferences
#-----------------------------------------
# set to non-empty to leave downloaded files after the update is done
#LEAVE_FILES="true"
# show debug messages (set to non-empty to enable)
DEBUG_IT=yes

# download site
DOWNLOAD_SITE="https://${SITE_NAME}${EPO_SERVER}:443/Software/Current/VSCANDAT1000/DAT/0000"

# space-delimited list of files to unzip
# format => <filename>:<permissions>
FILE_LIST="avvscan.dat:444 avvnames.dat:444 avvclean.dat:444"

LOG_FILE=/var/McAfee/agent/logs/VSCL_mgmt.log

#=============================================================================
# FUNCTIONS
#=============================================================================

Do-Cleanup() {
    #------------------------------------------------------------
    # if 'LEAVE_FILES' global is NOT set, erase downloaded files
    #------------------------------------------------------------

    if [[ -z "$LEAVE_FILES" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

Exit-WithError() {
    #----------------------------------------------------------
    # if $1 param is set, print error msg
    # in any case, exit with error
    #----------------------------------------------------------

    if [[ -n "$1" ]]; then
        Log-Print "$@"
    fi

    Do-Cleanup
    exit 1
}

Log-Print() {
    #----------------------------------------------------------
    # if 'DEBUG_IT' global is set, print params
    #----------------------------------------------------------

    local OUTPUT=$(printf "%s:%s" $SCRIPT_NAME "[$(date "+%FT%T")] $@")
    echo $OUTPUT >> "$LOG_FILE"
    echo $OUTPUT
}

Find-INISection() {
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

Get-CurrentDATVersion() {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    printf "%s.0\n" $(echo "$("$UVSCAN_DIR/$UVSCAN_EXE" --version)" | grep -i "dat set version:"  | cut -d' ' -f4)

    return 0
}

Download-File() {
    #------------------------------------------------------------
    # Function to download a specified file from repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #         $5 - executable to use to fetch file (wget or curl)
    #------------------------------------------------------------

    # type must be "bin" or "ascii"
    if [[ "$3" != "bin" ]] && [[ "$3" != "ascii" ]]; then
        Exit-WithError "Download type must be 'bin' or 'ascii'!"
    fi

    local FILE_NAME="$4/$2"
    local DOWNLOAD_URL="$1/$2"
    local FETCHER_CMD

    # download with wget
    case $5 in
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

    # Check the file size matches what we expect...
    SIZE=$(stat "$1" --printf "%s")

    if [[ -n "$SIZE" ]] && [[ "$SIZE" = "$2" ]]; then
        Log-Print "File '$1' size is correct ($2)"
    else
        Exit-WithError "Downloaded DAT size '$SIZE' should be '$1'!"
    fi

    # make MD5 check optional. return "success" if there's no support
    if [[ -z "$MD5CHECKER" ]] || [[ ! -x $(which $MD5CHECKER 2> /dev/null) ]]; then
        Log-Print "MD5 Checker not available, skipping MD5 check..."
        return 0
    fi

    # Check the MD5 checksum...
    MD5_CSUM=$($MD5CHECKER "$1" 2>/dev/null | cut -d' ' -f1)

    if [[ -n "$MD5_CSUM" ]] && [[ "$MD5_CSUM" = "$3" ]]; then
        Log-Print "File '$1' MD5 checksum is correct ($3)"
    else
        Exit-WithError "Downloaded DAT MD5 hash '$MD5_csum' should be '$3'!"
    fi

    return 0
}

Update-FromZip() {
    #---------------------------------------------------------------
    # Function to extract the listed files from the given zip file.
    #---------------------------------------------------------------
    # Params: $1 - Directory to unzip to
    #         $2 - Downloaded zip file
    #         $3 - Dist of files to unzip
    #              (format => <filename>:<chmod>)
    #---------------------------------------------------------------

    unset FILE_LIST

    # strip filename to a list
    for FNAME in $3; do
        FILE_NAME=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $1 } ')
        FILE_LIST="$FILE_LIST $FILE_NAME"
    done

    BACKUP_DIR="./backup"

    # Backup any files about to be updated...
    if [[ ! -d "$BACKUP_DIR" ]]; then
        Log-Print "Creating backup directory files to be updated..."
        mkdir -d -p "$BACKUP_DIR" 2> /dev/null
    fi

    if [[ -d "$BACKUP_DIR" ]]; then
        cp "$FILE_LIST" "backup" 2>/dev/null
    fi

    # Update the DAT files.
    Log-Print "Uncompressing '$2' to '$1'..."

    if ! unzip -o -d "$1" "$2" "$FILE_LIST" 2> /dev/null; then
        Exit-WithError "Error unzipping '$2' to '$1'!"
    fi

    # apply chmod permissions from list
    for FNAME in $3; do
        FILE_NAME=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $1 } ')
        PERMISSIONS=$(printf "%s\n" "$FNAME" | awk -F':' ' { print $NF } ')
        chmod "$PERMISSIONS" "$1/$FILE_NAME"
    done

    return 0
}

Check-For() {
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

Set-CustomProp1() {
    #------------------------------------------------------------
    # Set the value of McAfee custom Property #1
    #------------------------------------------------------------
    # Params:  $1 = value to set property
    #------------------------------------------------------------
    Log-Print "Setting EPO Custom Property #1 to '$1'..."

    if ! "$MACONFIG_PATH" -custom -prop1 "$1" 2> /dev/null; then
        Exit-WithError "Error setting EPO Custom Property #1 to '$1'!"
    fi

    return 0
}

Refresh-ToEPO() {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------

    # flags to use with CMDAGENT utility
    unset CMDAGENT_FLAGS
    CMDAGENT_FLAGS="-c -f -p -e"

    Log-Print "Refreshing agent data with EPO..."

    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAG_NAME in $CMDAGENT_FLAGS; do
        if ! "$CMDAGENT_PATH" "$FLAG_NAME" 2> /dev/null; then
            Exit-WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'!"
        fi
    done

    return 0
}

#=============================================================================
#  MAIN PROGRAM
#=============================================================================

# sanity checks
# check for wget
if command -v wget 2> /dev/null; then
    FETCHER="wget"
elif command -v curl 2> /dev/null; then
    FETCHER="curl"
else
    Exit-WithError "No valid URL fetcher available!"
fi

if [[ -z "$DOWNLOAD_ONLY" ]]; then
    # check for MACONFIG
    Check-For $MACONFIG_PATH "MACONFIG utility"

    # check for CMDAGENT
    Check-For $CMDAGENT_PATH "CMDAGENT utility"

    # check for uvscan
    if ! Check-For $UVSCAN_DIR/$UVSCAN_EXE "uvscan executable" --no-terminate; then
        # uvscan not found
        # set custom property to error value, then exit with error
        Log-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
        Log-Print "Setting McAfee Custom Property #1 to 'VSCL:NOT INSTALLED'..."
        Set-CustomProp1 "VSCL:NOT INSTALLED"
        Refresh-ToEPO
        exit 0
    fi
fi

# make temp dir if it doesn't exist
Log-Print "Checking for temporary directory '$TMP_DIR'..."

if [[ ! -d "$TMP_DIR" ]]; then
    Log-Print "Creating temporary directory '$TMP_DIR'..."

    if ! mkdir -p "$TMP_DIR" 2> /dev/null; then
        Exit-WithError "Error creating temporary directory '$TMP_DIR'!"
    fi
fi

if [[ ! -d "$TMP_DIR" ]]; then
    Exit-WithError "Error creating temporary directory '$TMP_DIR'!"
fi

# download current DAT version file from repository, exit if not available
Log-Print "Downloading DAT versioning file '$VERSION_FILE' from '$DOWNLOAD_SITE'..."

#DOWNLOAD_OUT="$?"

if ! Download-File "$DOWNLOAD_SITE" "$VERSION_FILE" "ascii" "$TMP_DIR" "$FETCHER"; then
    Exit-WithError "+++Error downloading '$VERSION_FILE' from '$DOWNLOAD_SITE'!"
fi

# Did we get the version file?
if [[ ! -r "$LOCAL_VERSION_FILE" ]]; then
    Exit-WithError "***Error downloading '$VERSION_FILE' from '$DOWNLOAD_SITE'!"
fi

if [[ -z "$DOWNLOAD_ONLY" ]]; then
    # Get the version of the installed DATs...
    Log-Print "Determining the currently installed DAT version..."

    unset CURRENT_DAT
    CURRENT_DAT=$(Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE" "$UVSCAN_SWITCHES")

    if [[ -z "$CURRENT_DAT" ]] ; then
        Log-Print "Unable to determine currently installed DAT version!"
        CURRENT_DAT="0000.0"
    fi

    CURRENT_MAJOR=$(echo "$CURRENT_DAT" | cut -d. -f-1)
    CURRENT_MINOR=$(echo "$CURRENT_DAT" | cut -d. -f2-)
fi

# extract DAT info from avvdat.ini
Log-Print "Determining the available DAT version..."
unset INI_SECTION
Log-Print "Finding section for current DAT version in '$LOCAL_VERSION_FILE'..."
INI_SECTION=$(Find-INISection $VER_SECTION < "$LOCAL_VERSION_FILE")

if [[ -z "$INI_SECTION" ]]; then
    Exit-WithError "Unable to find section '$INI_SECTION' in '$LOCAL_VERSION_FILE'!"
fi

unset MAJOR_VER FILE_NAME FILE_PATH FILE_SIZE MD5
# Some INI sections have the MinorVersion field missing.
# To work around this, we will initialise it to 0.
MINOR_VER=0

unset INI_FIELD

# Parse the section and keep what we are interested in.
for INI_FIELD in $INI_SECTION; do
    FIELD_NAME=$(echo "$INI_FIELD" | awk -F'=' ' { print $1 } ')
    FIELD_VALUE=$(echo "$INI_FIELD" | awk -F'=' ' { print $2 } ')

    case $FIELD_NAME in
        "DATVersion") MAJOR_VER="$FIELD_VALUE"  # available: major
            ;; 
        "MinorVersion") MINOR_VER="$FIELD_VALUE" # available: minor
            ;;
        "FileName") FILE_NAME="$FIELD_VALUE" # file to download
            ;;
        "FilePath") FILE_PATH="$FIELD_VALUE" # path on FTP server
            ;;
        "FileSize") FILE_SIZE="$FIELD_VALUE" # file size
            ;;
        "MD5") MD5="$FIELD_VALUE" # MD5 checksum
            ;;
        *) true  # ignore any other fields
            ;;
    esac
done

# sanity check
# All extracted fields have values?
if [[ -z "$MAJOR_VER" ]] || [[ -z "$MINOR_VER" ]] || [[ -z "$FILE_NAME" ]] || [[ -z "$FILE_PATH" ]] || [[ -z "$FILE_SIZE" ]] || [[ -z "$MD5" ]]; then
    Exit-WithError "Section '[$INI_SECTION]' in '$LOCAL_VERSION_FILE' has incomplete data!"
fi

if [[ -z "$DOWNLOAD_ONLY" ]]; then
    # Installed version is less than current DAT version?
    if (( CURRENT_MAJOR < MAJOR_VER )) || ( (( CURRENT_MAJOR == MAJOR_VER )) && (( CURRENT_MINOR < MINOR_VER )) ); then
        PERFORM_UPDATE="yes"
    fi
fi

# OK to perform update?
if [[ -n "$PERFORM_UPDATE" ]] || [[ -n "$DOWNLOAD_ONLY" ]]; then
    if [[ -n "$PERFORM_UPDATE" ]]; then
        Log-Print "Performing an update ($CURRENT_DAT -> $MAJOR_VER.$MINOR_VER)..."
    fi

    # Download the dat files...
    Log-Print "Downloading the current DAT '$FILE_NAME' from '$DOWNLOAD_SITE'..."

    Download-File "$DOWNLOAD_SITE" "$FILE_NAME" "bin" "$TMP_DIR" "$FETCHER"
    DOWNLOAD_OUT="$?"

    if [[ "$DOWNLOAD_OUT" != "0" ]]; then
        Exit-WithError "Error downloading '$FILE_NAME' from '$DOWNLOAD_SITE'!"
    fi

    DAT_ZIP="$TMP_DIR/$FILE_NAME"

    # Did we get the dat update file?
    if [[ ! -r "$DAT_ZIP" ]]; then
        Exit-WithError "Unable to download DAT file '$DAT_ZIP'!"
    fi

    Validate-File "$DAT_ZIP" "$FILE_SIZE" "$MD5"
    VALIDATE_OUT="$?"

    if [[ "$VALIDATE_OUT" != "0" ]]; then
        Exit-WithError "DAT download failed - Validation failed for '$TMP_DIR/$FILE_NAME'!"
    fi

    # Exit if we only wanted to download
    if [[ -n "$DOWNLOAD_ONLY" ]]; then
        #Do-Cleanup
        Log-Print "DAT downloaded to '$DAT_ZIP'.  Exiting.."
        exit 0
    fi

    Update-FromZip "$UVSCAN_DIR" "$DAT_ZIP" "$FILE_LIST"
    UPDATE_OUT="$?"

    if [[ "$UPDATE_OUT" != "0" ]] ; then
        Exit-WithError "Error unzipping DATs from file '$TMP_DIR/$DAT_ZIP'!"
    fi

    # Check the new version matches the downloaded one.
    Log-Print "Starting up uvscan with new DAT files..."
    NEW_VERSION=$(Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE" "$UVSCAN_SWITCHES")

    if [[ -z "$NEW_VERSION" ]]; then
        # Could not determine current value for DAT version from uvscan
        # set custom property to error value, then exit with error
        Log-Print "Unable to determine currently installed DAT version!"
        NEW_VERSION="VSCL:INVALID DAT"
    else
        Log-Print "Checking that the installed DAT matches the available DAT version..."
        NEW_MAJOR=$(echo "$NEW_VERSION" | cut -d. -f-1)
        NEW_MINOR=$(echo "$NEW_VERSION" | cut -d. -f2-)

        if (( NEW_MAJOR == MAJOR_VER )) && (( NEW_MINOR == MINOR_VER)); then
            Log-Print "DAT update succeeded ($CURRENT_DAT -> $NEW_VERSION)!"
        else
            Exit-WithError "DAT update failed - installed version different than expected!"
        fi

        NEW_VERSION="VSCL=$NEW_VERSION"
    fi

    # Set McAfee Custom Property #1 to '$NEW_VERSION'...
    Set-CustomProp1 "$NEW_VERSION"

    # Refresh agent data with EPO
    Refresh-ToEPO
    exit 0
else
    if [[ -z "$PERFORM_UPDATE" ]]; then
        Log-Print "Installed DAT is already up to date ($CURRENT_DAT)!  Exiting..."
    fi
fi

Do-Cleanup
exit 0
