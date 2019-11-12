#!/bin/bash

#=============================================================================
# Name:         VSCL-Update-DAT.sh
#-----------------------------------------------------------------------------
# Purpose:      Update the DAT files for the McAfee VirusScan Command Line
#                       Scanner 6.1.3 on SaaS Linux PPM App servers from EPO
#-----------------------------------------------------------------------------
# Creator:      Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:         21-OCT-2019
#-----------------------------------------------------------------------------
# Version:      1.2
#-----------------------------------------------------------------------------
# PreReqs:      Linux
#               CA PPM Application Server
#               VSCL antivirus scanner installed
#               Latest VSCL DAT .ZIP file
#               unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#               awk, echo, cut, ls, printf, wget
# Params:       none
#-----------------------------------------------------------------------------
# Switches:     -d:  download current DATs and exit
#               -l:  leave any files extracted intact at exit
#-----------------------------------------------------------------------------
# Imports:      ./VSCL-local.sh:  local per-site variables
#               ./VSCL-local.sh:  library functions
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
. ./VSCL-local.sh
. ./VSCL-lib.sh

#-----------------------------------------
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

#-----------------------------------------
# Globals variables
#-----------------------------------------
# name and path of this script
SCRIPT_ABBR="VCSLUDAT"

# name of the repo file with current DAT version
VERSION_FILE="avvdat.ini"

# Name of the file in the repository to extract current DAT version from
LOCAL_VERSION_FILE="$TMP_DIR/$VERSION_FILE"

# section of avvdat.ini from repository to examine for DAT version
VER_SECTION="AVV-ZIP"

# Preferences
#-----------------------------------------
# set to non-empty to leave downloaded files after the update is done
#LEAVE_FILES="true"

# download site
# shellcheck disable=SC2153
DOWNLOAD_SITE="https://${SITE_NAME}${EPO_SERVER}:443/Software/Current/VSCANDAT1000/DAT/0000"

# space-delimited list of files to unzip
# format => <filename>:<permissions>
FILE_LIST="avvscan.dat:444 avvnames.dat:444 avvclean.dat:444"

#=============================================================================
# FUNCTIONS
#=============================================================================

function Update-FromZip() {
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

    if ! unzip -o -d "$1" "$2" $FILE_LIST 2> /dev/null; then
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

#=============================================================================
#  MAIN PROGRAM
#=============================================================================


if [[ -z "$DOWNLOAD_ONLY" ]]; then
    # check for MACONFIG
    Check-For $MACONFIG_PATH "MACONFIG utility"

    # check for CMDAGENT
    Check-For $CMDAGENT_PATH "CMDAGENT utility"

    # check for uvscan
    if ! Check-For $UVSCAN_DIR/$UVSCAN_EXE "uvscan executable" --no-terminate; then
        # uvscan not found
        # set custom property to error value, then exit
        Log-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
        Log-Print "Setting McAfee Custom Property #1 to 'VSCL:NOT INSTALLED'..."
        Set-CustomProp 1 "VSCL:NOT INSTALLED"
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
    CURRENT_DAT=$(Get-CurrentDATVersion)

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

    Download-File "$DOWNLOAD_SITE" "$FILE_NAME" "bin" "$TMP_DIR"
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

        if ! (( NEW_MAJOR == MAJOR_VER )) && (( NEW_MINOR == MINOR_VER)); then
            Log-Print "DAT update succeeded ($CURRENT_DAT -> $NEW_VERSION)!"
        else
            Exit-WithError "DAT update failed - installed version different than expected!"
        fi

        NEW_VERSION="VSCL=$NEW_VERSION"
    fi

    # Set McAfee Custom Property #1 to '$NEW_VERSION'...
    Set-CustomProp 1 "$NEW_VERSION"

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
