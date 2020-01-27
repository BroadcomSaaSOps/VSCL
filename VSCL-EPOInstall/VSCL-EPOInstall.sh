#!/bin/bash

#=============================================================================
# NAME:     VSCL-EPOInstall.sh
#-----------------------------------------------------------------------------
# Purpose:  Installer for McAfee VirusScan Command Line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     10-JAN-2020
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
# Switches: -n: do NOT update DAT files (defaults to updating if supplied in package)
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-local.sh:  local per-site variables
#           ./VSCL-local.sh:  library functions
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
# shellcheck disable=SC1091
. ./VSCL-local.sh
. ./VSCL-lib.sh

#-----------------------------------------
# Process command line options
#-----------------------------------------
# shellcheck disable=2034
while getopts :n OPTION_VAR; do
    case "$OPTION_VAR" in
        "n") DAT_UPDATE=0    # do NOT update DAT files
            ;;
        *) Exit_WithError "Unknown option specified!"
            ;;
    esac
done

#-----------------------------------------
# Global variables
#-----------------------------------------
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCLEPOI"

# Command to call to download and update to current .DATs from EPO
DAT_UPDATE_CMD="VSCL-Update-DAT.sh"

# Default to updating DATs (if supplied)
if [[ -z "$DAT_UPDATE" ]]; then
    DAT_UPDATE=1
fi

# Default filler for Custom Property #1
NEW_VER="VSCL:INVALID DAT"

# full path of downloaded versioning file
LOCAL_VER_FILE="$__VSCL_TEMP_DIR/$__VSCL_PKG_VER_FILE"

# download site
# shellcheck disable=SC2153
DOWNLOAD_SITE="https://${__VSCL_SITE_NAME}${__VSCL_EPO_SERVER}:443/Software/Current/$__VSCL_INSTALL_PKG$__VSCL_INSTALL_VER/Install/0000"


#=============================================================================
# MAIN
#=============================================================================

Log_Info "==========================="
Log_Info "Beginning VSCL installation"
Log_Info "==========================="

# download latest installer version file from EPO "VSCL Package" directory
if ! Download_File "$DOWNLOAD_SITE" "$__VSCL_PKG_VER_FILE" "ascii" "$__VSCL_TEMP_DIR"; then
    Exit_WithError "Error downloading '$__VSCL_PKG_VER_FILE' from '$DOWNLOAD_SITE'!"
fi

if [[ ! -r "$LOCAL_VER_FILE" ]]; then
    # unable to download version file from EPO, abort
    Exit_WithError "Error downloading '$__VSCL_PKG_VER_FILE' from '$DOWNLOAD_SITE'!"
fi

# extract DAT info from avvdat.ini
Log_Info "Determining the available installer version..."
unset INI_SECTION
Log_Info "Finding section for current installer version in '$LOCAL_VER_FILE'..."
echo "pwd = '`pwd`'"
INI_SECTION=$(Find_INISection "$__VSCL_PKG_VER_SECTION" < "$LOCAL_VER_FILE")

if [[ -z "$INI_SECTION" ]]; then
    Exit_WithError "Unable to find section '$__VSCL_PKG_VER_SECTION' in '$LOCAL_VER_FILE'!"
fi

unset INI_FIELD PACKAGE_NAME PACKAGE_VER FILE_NAME FILE_PATH FILE_SIZE MD5

# Parse the section and keep what we are interested in.
for INI_FIELD in $INI_SECTION; do
    FIELD_NAME=$(echo "$INI_FIELD" | awk -F'=' ' { print $1 } ')
    FIELD_VALUE=$(echo "$INI_FIELD" | awk -F'=' ' { print $2 } ')

    case $FIELD_NAME in
        "Name") PACKAGE_NAME="$FIELD_VALUE"  # name of installer
            ;; 
        "InstallVersion") PACKAGE_VER="$FIELD_VALUE" # version of installer
            ;;
        "FileName") FILE_NAME="$FIELD_VALUE" # file to download
            ;;
        *) true  # ignore any other fields
            ;;
    esac
done

# sanity check
# All extracted fields have values?
if [[ -z "$PACKAGE_NAME" ]] || [[ -z "$PACKAGE_VER" ]] || [[ -z "$FILE_NAME" ]]; then
    Exit_WithError "Section '[$INI_SECTION]' in '$LOCAL_VER_FILE' has incomplete data!"
fi

Log_Info "New Installer Version Available: '$PACKAGE_VER'"

# Download the dat files...
Log_Info "Downloading the current installer '$FILE_NAME' from '$DOWNLOAD_SITE'..."

if ! Download_File "$DOWNLOAD_SITE" "$FILE_NAME" "bin" "$__VSCL_TEMP_DIR"; then
    Exit_WithError "Error downloading '$__VSCL_TEMP_DIR/$FILE_NAME' from '$DOWNLOAD_SITE'!"
fi

# move install files to unzip into temp
# >>> DO NOT add quote below, [ -f ] conditionals don't work with quoting
# >>> this must stay [..], [[..]] doesnt do globbing
# shellcheck disable=SC2086
if [ ! -f $__VSCL_TEMP_DIR/$FILE_NAME ]; then
    Exit_WithError "ERROR: Installer archive '$__VSCL_TEMP_DIR/$FILE_NAME' does not exist!"
fi

# untar installer archive in-place and install uvscan with default settings
Log_Info "Extracting installer '$__VSCL_TEMP_DIR/$FILE_NAME' to directory '$__VSCL_TEMP_DIR'..."

if ! cd "$__VSCL_TEMP_DIR"; then
    Exit_WithError "Unable to change to temp directory '$__VSCL_TEMP_DIR'!"
fi

if ! Capture_Command "tar" "-xvzf ./$FILE_NAME"; then
    Exit_WithError "Error extracting installer '$__VSCL_TEMP_DIR/$FILE_NAME' to directory '$__VSCL_TEMP_DIR'!"
fi

Log_Info "Installing VSCL..."

if ! Capture_Command "./$__VSCL_INSTALL_CMD" "-y"; then
    Exit_WithError "Error installing VirusScan Command Line Scanner!"
fi

# remove temp directory
#Log_Info "Removing temp directory..."
cd ..
#rm -rf "$__VSCL_TEMP_DIR"

if [[ "$DAT_UPDATE" = "0" ]]; then
    Log_Info "Option specified to NOT update DAT files.  Continuing..."
else
    # OK to update DAT files
    "./$DAT_UPDATE_CMD"
    
    # Run script to update DAT from EPO
    #if ! Capture_Command "./$DAT_UPDATE_CMD" "dummyarg"; then
    #    Exit_WithError "Error updating DATs for VirusScan Command Line Scanner!"
    #fi
    
    #NEW_VER=$(Get_CurrDATVer)
    #fi
fi

if [[ -f "./$__VSCL_WRAPPER" ]]; then
    # make uvwrap.sh executable and copy to uvscan directory
    Log_Info "Setting up shim '$__VSCL_WRAPPER' for uvscan..."
    chmod +x "./$__VSCL_WRAPPER"
else
    Exit_WithError "File '$__VSCL_WRAPPER' not available.  Aborting installer!"
fi

if [[ -f "$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER" ]]; then
    Log_Info "Deleting any existing file at '$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER'..."
    
    if ! rm -f "$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER"; then
        Log_Warning "Existing file '$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER' could not be deleted!  Continuing..."
    fi
fi

if [[ ! -f "$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER" ]]; then
    Log_Info "Copying wrapper file './$__VSCL_WRAPPER' to '$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER'..."
    
    if ! cp -f "./$__VSCL_WRAPPER" "$__VSCL_UVSCAN_DIR"; then
        Exit_WithError "Could not copy wrapper file './$__VSCL_WRAPPER' to '$__VSCL_UVSCAN_DIR/$__VSCL_WRAPPER'!"
    fi
fi

# Set McAfee Custom Property #1 to '$NEW_VER'...
#Set_CustomProp 1 "$NEW_VER"

# Refresh agent data with EPO
Refresh_ToEPO

# Clean up global variables and exit cleanly
Exit_Script 0
