#!/bin/bash

#=============================================================================
# NAME:     VSCL-EPOInstall.sh
#-----------------------------------------------------------------------------
# Purpose:  Installer for McAfee VirusScan Command Line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     03-FEB-2020
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
# Imports:  ./VSCL-lib.sh:              library functions
#           ./VSCL-Update-DAT.sh:       self-contained DAT updater
#=============================================================================


#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
# shellcheck disable=SC2091
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Installer must NOT be sourced. It must be run standalone. Aborting installer!"
    return 1
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
unset INCLUDE_PATH
INCLUDE_PATH="${BASH_SOURCE%/*}"
. "$INCLUDE_PATH/VSCL-lib.sh"
# shellcheck disable=SC1091
. "$INCLUDE_PATH/VSCL-Update-DAT.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
__VSCL_SCRIPT_ABBR="VSCLEPOI"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function Install_With_EPO {
    #----------------------------------------------------------
    # Download the latest installer from EPO and run it
    #----------------------------------------------------------
    # Params: $@ - all arguments passed to script
    #----------------------------------------------------------
    local DAT_UPDATE_CMD DAT_UPDATE NEW_VER LOCAL_VER_FILE DOWNLOAD_SITE
    local SUPPORT_FILE TARGET_FILE

    # Command to call to download and update to current .DATs from EPO
    # shellcheck disable=SC2034
    DAT_UPDATE_CMD="VSCL-Update-DAT.sh"

    # Default to updating DATs (if supplied)
    DAT_UPDATE="${DAT_UPDATE-1}"

    # Default filler for Custom Property #1
    # shellcheck disable=SC2034
    NEW_VER="$__VSCL_INVALID_CODE"

    # full path of downloaded versioning file
    LOCAL_VER_FILE="$__VSCL_TEMP_DIR/$__VSCL_PKG_VER_FILE"

    # download site
    # shellcheck disable=SC2153
    DOWNLOAD_SITE="https://${__VSCL_SITE_NAME}${__VSCL_EPO_SERVER}:443/Software/Current/$__VSCL_INSTALL_PKG$__VSCL_INSTALL_VER/Install/0000"

    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    local OPTION_VAR

    while getopts :n OPTION_VAR; do
        case "$OPTION_VAR" in
            "n") DAT_UPDATE=0    # do NOT update DAT files
                ;;
            *) Exit_WithError "Unknown option specified. Aborting installer!"
                ;;
        esac
    done

    Log_Info "==========================="
    Log_Info "Beginning VSCL installation"
    Log_Info "==========================="

    # download latest installer version file from EPO "VSCL Package" directory
    if ! Download_File "$DOWNLOAD_SITE" "$__VSCL_PKG_VER_FILE" "ascii" "$__VSCL_TEMP_DIR"; then
        Exit_WithError "Error downloading '$__VSCL_PKG_VER_FILE' from '$DOWNLOAD_SITE'. Aborting installer!"
    fi

    if [[ ! -r "$LOCAL_VER_FILE" ]]; then
        # unable to download version file from EPO, abort
        Exit_WithError "Error downloading '$__VSCL_PKG_VER_FILE' from '$DOWNLOAD_SITE'. Aborting installer!"
    fi

    # extract DAT info from avvdat.ini
    Log_Info "Determining the available installer version..."
    unset INI_SECTION
    Log_Info "Finding section for current installer version in '$LOCAL_VER_FILE'..."
    #echo "pwd = '`pwd`'"
    INI_SECTION=$(Find_INISection "$__VSCL_PKG_VER_SECTION" < "$LOCAL_VER_FILE")

    if [[ -z "$INI_SECTION" ]]; then
        Exit_WithError "Unable to find section '$__VSCL_PKG_VER_SECTION' in '$LOCAL_VER_FILE'. Aborting installer!"
    fi

    local INI_FIELD PACKAGE_NAME PACKAGE_VER INSTALL_FILE

    # Parse the section and keep what we are interested in.
    for INI_FIELD in $INI_SECTION; do
        FIELD_NAME=$(echo "$INI_FIELD" | awk -F'=' ' { print $1 } ')
        FIELD_VALUE=$(echo "$INI_FIELD" | awk -F'=' ' { print $2 } ')

        case $FIELD_NAME in
            "Name") PACKAGE_NAME="$FIELD_VALUE"  # name of installer
                ;; 
            "InstallVersion") PACKAGE_VER="$FIELD_VALUE" # version of installer
                ;;
            "FileName") INSTALL_FILE="$FIELD_VALUE" # file to download
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    done

    # sanity check
    # All extracted fields have values?
    if [[ -z "$PACKAGE_NAME" ]] || [[ -z "$PACKAGE_VER" ]] || [[ -z "$INSTALL_FILE" ]]; then
        Exit_WithError "Section '[$INI_SECTION]' in '$LOCAL_VER_FILE' has incomplete data. Aborting installer!"
    fi

    Log_Info "New Installer Version Available: '$PACKAGE_VER'"

    # Download the dat files...
    Log_Info "Downloading the current installer '$INSTALL_FILE' from '$DOWNLOAD_SITE'..."

    if ! Download_File "$DOWNLOAD_SITE" "$INSTALL_FILE" "bin" "$__VSCL_TEMP_DIR"; then
        Exit_WithError "Cannot download '$__VSCL_TEMP_DIR/$INSTALL_FILE' from '$DOWNLOAD_SITE'. Aborting installer!"
    fi

    # move install files to unzip into temp
    # shellcheck disable=SC2086
    if [[ ! -f "$__VSCL_TEMP_DIR/$INSTALL_FILE" ]]; then
        Exit_WithError "Installer archive '$__VSCL_TEMP_DIR/$INSTALL_FILE' does not exist. Aborting installer!"
    fi

    # untar installer archive in-place and install uvscan with default settings
    Log_Info "Extracting installer '$__VSCL_TEMP_DIR/$INSTALL_FILE' to directory '$__VSCL_TEMP_DIR'..."

    if ! cd "$__VSCL_TEMP_DIR"; then
        Exit_WithError "Unable to change to temp directory '$__VSCL_TEMP_DIR'. Aborting installer!"
    fi

    if ! Capture_Command "tar" "-xvzf ./$INSTALL_FILE"; then
        Exit_WithError "Error extracting installer '$__VSCL_TEMP_DIR/$INSTALL_FILE' to directory '$__VSCL_TEMP_DIR'. Aborting installer!"
    fi

    Log_Info "Installing VSCL..."

    if ! Capture_Command "./$__VSCL_INSTALL_CMD" "-y"; then
        Exit_WithError "Error installing VirusScan Command Line Scanner. Aborting installer!"
    fi

    if [[ "$DAT_UPDATE" = "0" ]]; then
        Log_Info "Option specified to NOT update DAT files. Continuing..."
    else
        # OK to update DAT files
        unset ERR
        Update_DAT
        ERR=$?
        
        # Run script to update DAT from EPO
        if [[ "$ERR" != "0" ]]; then
            Exit_WithError "Error updating DATs for VirusScan Command Line Scanner. Aborting installer!"
        fi
        
        #NEW_VER=$(Get_CurrDATVer)
        #fi
    fi

    # return to original directory
    cd ..

    # Copy support files to uvscan directory
    for SUPPORT_FILE in $__VSCL_SCAN_SUPPORT_FILES; do
        TARGET_FILE="$__VSCL_UVSCAN_DIR/$SUPPORT_FILE"
        Log_Info "Copying support file '$SUPPORT_FILE' to '$TARGET_FILE'..."

        if [[ ! -f "./$SUPPORT_FILE" ]]; then
            # source support file not available, error
            Exit_WithError "File '$SUPPORT_FILE' not available. Aborting installer!"
        fi

        if [[ -f "$TARGET_FILE" ]]; then
            # delete any existing copy of support file
            Log_Info "Deleting existing file '$TARGET_FILE'..."
            
            if ! rm -f "$TARGET_FILE"; then
                # unable to remove target file, error
                Log_Error "Existing file '$TARGET_FILE' could not be deleted! Aborting installer!"
            fi
        fi

        if ! cp -f "./$SUPPORT_FILE" "$__VSCL_UVSCAN_DIR"; then
            # error copying support file to target, error
            Exit_WithError "Could not copy support file './$SUPPORT_FILE' to '$__VSCL_UVSCAN_DIR/$SUPPORT_FILE'. Aborting installer!"
        fi

        if ! chmod +x "$__VSCL_UVSCAN_DIR/$SUPPORT_FILE"; then
            # unable to make target support file executable, error
            Exit_WithError "File '$SUPPORT_FILE' not available. Aborting installer!"
        fi
    done

    # Clean up global variables and exit cleanly
    Exit_Script $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
Install_With_EPO "$@"
