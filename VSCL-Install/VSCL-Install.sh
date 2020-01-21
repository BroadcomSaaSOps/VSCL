#!/bin/bash

#=============================================================================
# NAME:     VSCL-Install.sh
#-----------------------------------------------------------------------------
# Purpose:  Installer for McAfee VirusScan Command Line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     16-Dec-2019
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
#           ./VSCL-lib.sh:    library functions
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
        "n") __VSCL_DAT_UPDATE=0    # do NOT update DAT files
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
__VSCL_SCRIPT_ABBR="VSCLINST"

# Default ClamAV location
CLAMAV_HOME="/fs0/od/clamav/bin"

# Default path to ClamAV executable
CLAMSCAN_EXE="$CLAMAV_HOME/clamscan"

# Path to backup original ClamAV scanner shell file
CLAMSCAN_BACKUP="$CLAMSCAN_EXE.orig"

# Pattern for downloaded VSCL binary installer tarball
INSTALLER_ZIP="vscl-*.tar.gz"

# Pattern for downloaded DAT .ZIP file
__VSCL_DAT_ZIP="avvdat-*.zip"

# Raw command to install VSCL from installer tarball
__VSCL_INSTALL_CMD="install-uvscan"

# Command to call to download and update to current .DATs from EPO
#__VSCL_DAT_UPDATE_CMD="VSCL-Update-DAT.sh"    <--  for EPO download

# v---- for integrated download
__VSCL_DAT_UPDATE_CMD="update-uvscan-dat.sh"

# Default to updating DATs (if supplied)
if [[ -z "$__VSCL_DAT_UPDATE" ]]; then
    __VSCL_DAT_UPDATE=1
fi

# Default filler for Custom Property #1
NEW_VERSION="VSCL:INVALID DAT"

#=============================================================================
# MAIN
#=============================================================================

Log_Print "==========================="
Log_Print "Beginning VSCL installation"
Log_Print "==========================="

# move install files to unzip into temp
# >>> DO NOT add quote below, [ -f ] conditionals don't work with quoting
# >>> this must stay [..], [[..]] doesnt do globbing
# shellcheck disable=SC2086
if [ ! -f ./$INSTALLER_ZIP ]; then
    Exit_WithError "ERROR: Installer archive './$INSTALLER_ZIP' does not exist!"
fi

Log_Print "Copying installer archive './$INSTALLER_ZIP' to temp directory '$TEMP_DIR'..."
    
if ! cp -f ./$INSTALLER_ZIP "$TEMP_DIR"; then
    Exit_WithError "ERROR: Error copying installer archive './$INSTALLER_ZIP' to temp directory '$TEMP_DIR'!"
fi

#TODO: Download installer from EPO
#TODO: For now installation only works if installer supplied with this script

# untar installer archive in-place and install uvscan with default settings
Log_Print "Extracting installer to directory '$TEMP_DIR'..."

if ! cd "$TEMP_DIR"; then
    Exit_WithError "Unable to change to temp directory './$TEMP_DIR'!"
fi

if ! tar -xvzf ./$INSTALLER_ZIP; then
    Exit_WithError "Error extracting installer to directory '$TEMP_DIR'!"
fi

Log_Print "Installing VSCL..."

if ! "./$__VSCL_INSTALL_CMD" -y; then
    Exit_WithError "Error installing VirusScan Command Line Scanner!"
fi

# remove temp directory
#Log_Print "Removing temp directory..."
#cd ..
#rm -rf "./$TEMP_DIR"

if [[ "$__VSCL_DAT_UPDATE" = "0" ]]; then
    Log_Print "NOTE: Option specified to NOT update DAT files.  Continuing..."
else
    # OK to update DAT files
    
    #TODO: Download latest DATs from EPO
    #TODO: For now updating only works if .ZIP supplied with installer
    
    if [[ -f "./$__VSCL_DAT_ZIP" ]]; then
        # Update the scanner with the latest AV definitions supplied with installer
        if ! ./$__VSCL_DAT_UPDATE_CMD "./$__VSCL_DAT_ZIP"; then
            Exit_WithError "Error unpacking DAT files to uvscan directory!"
        fi
        
        NEW_VERSION=$(Get_CurrentDATVersion)
    fi
fi

if [[ -f "./$__VSCL_WRAPPER" ]]; then
    # make uvwrap.sh executable and copy to uvscan directory
    Log_Print "Setting up shim __VSCL_WRAPPER for uvscan..."
    chmod +x "./$__VSCL_WRAPPER"
else
    Exit_WithError "File '$__VSCL_WRAPPER' not available.  Aborting installer!"
fi

if [[ -f "$UVSCAN_DIR/$__VSCL_WRAPPER" ]]; then
    Log_Print "Deleting any existing file at '$UVSCAN_DIR/$__VSCL_WRAPPER'..."
    
    if ! rm -f "$UVSCAN_DIR/$__VSCL_WRAPPER"; then
        Log_Print "WARNING: Existing file '$UVSCAN_DIR/$__VSCL_WRAPPER' could not be deleted!  Continuing..."
    fi
# fi

if [[ ! -f "$UVSCAN_DIR/$__VSCL_WRAPPER" ]]; then
    Log_Print "Copying __VSCL_WRAPPER file './$__VSCL_WRAPPER' to '$UVSCAN_DIR/$__VSCL_WRAPPER'..."
    
    if ! cp -f "./$__VSCL_WRAPPER" "$UVSCAN_DIR"; then
        Exit_WithError "Could not copy __VSCL_WRAPPER file './$__VSCL_WRAPPER' to '$UVSCAN_DIR/$__VSCL_WRAPPER'!"
    fi
fi

Log_Print "Copying VSCL Library Functions file './VSCL-lib.sh' to '$UVSCAN_DIR/VSCL-lib.sh'..."

if ! cp -f "./VSCL-lib.sh" "$UVSCAN_DIR"; then
    Exit_WithError "Could not copy VSCL Library Functions file './VSCL-lib.sh' to '$UVSCAN_DIR/VSCL-lib.sh'!"
fi

# Set McAfee Custom Property #1 to '$NEW_VERSION'...
Set_CustomProp 1 "$NEW_VERSION"

# Refresh agent data with EPO
Refresh_ToEPO

# Clean up global variables and exit cleanly
unset __VSCL_SCRIPT_ABBR CLAMAV_HOME CLAMSCAN_EXE CLAMSCAN_BACKUP INSTALLER_ZIP __VSCL_DAT_ZIP __VSCL_INSTALL_CMD __VSCL_DAT_UPDATE_CMD __VSCL_WRAPPER __VSCL_DAT_UPDATE NEW_VERSION
Exit_Script 0
