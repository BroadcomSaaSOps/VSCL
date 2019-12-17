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
SCRIPT_ABBR="VSCLINST"

# Default ClamAV location
CLAMAV_HOME="/fs0/od/clamav/bin"

# Default path to ClamAV executable
CLAMSCAN_EXE="$CLAMAV_HOME/clamscan"

# Path to backup original ClamAV scanner shell file
CLAMSCAN_BACKUP="$CLAMSCAN_EXE.orig"

# Pattern for downloaded VSCL binary installer tarball
INSTALLER_ZIP="vscl-*.tar.gz"

# Pattern for downloaded DAT .ZIP file
DAT_ZIP="avvdat-*.zip"

# Raw command to install VSCL from installer tarball
INSTALL_CMD="install-uvscan"

# Command to call to download and update to current .DATs from EPO
#DAT_UPDATE_CMD="VSCL-Update-DAT.sh"    <--  for EPO download

# v---- for integrated download
DAT_UPDATE_CMD="update-uvscan-dat.sh"

# Filename of scan wrapper to put in place of ClamAV executable
WRAPPER="uvwrap.sh"

# Default to updating DATs (if supplied)
if [[ -z "$DAT_UPDATE" ]]; then
    DAT_UPDATE=1
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

if ! "./$INSTALL_CMD" -y; then
    Exit_WithError "Error installing VirusScan Command Line Scanner!"
fi

# remove temp directory
#Log_Print "Removing temp directory..."
#cd ..
#rm -rf "./$TEMP_DIR"

if [[ "$DAT_UPDATE" = "0" ]]; then
    Log_Print "NOTE: Option specified to NOT update DAT files.  Continuing..."
else
    # OK to update DAT files
    
    #TODO: Download latest DATs from EPO
    #TODO: For now updating only works if .ZIP supplied with installer
    
    if [[ -f "./$DAT_ZIP" ]]; then
        # Update the scanner with the latest AV definitions supplied with installer
        if ! ./$DAT_UPDATE_CMD "./$DAT_ZIP"; then
            Exit_WithError "Error unpacking DAT files to uvscan directory!"
        fi
        
        NEW_VERSION=$(Get_CurrentDATVersion)
    fi
fi

# if [[ -f "./$WRAPPER" ]]; then
    # # make uvwrap.sh executable and copy to uvscan directory
    # Log_Print "Setting up shim wrapper for uvscan..."
    # chmod +x "./$WRAPPER"
# else
    # Exit_WithError "File '$WRAPPER' not available.  Aborting installer!"
# fi

# if [[ -f "$UVSCAN_HOME/$WRAPPER" ]]; then
    # Log_Print "Deleting any existing file at '$UVSCAN_HOME/$WRAPPER'..."
    
    # if ! rm -f "$UVSCAN_HOME/$WRAPPER"; then
        # Log_Print "WARNING: Existing file '$UVSCAN_HOME/$WRAPPER' could not be deleted!  Continuing..."
    # fi
# fi

# if [[ ! -f "$UVSCAN_HOME/$WRAPPER" ]]; then
    # Log_Print "Copying wrapper file './$WRAPPER' to '$UVSCAN_HOME/$WRAPPER'..."
    
    # if ! cp -f "./$WRAPPER" "$UVSCAN_HOME"; then
        # Exit_WithError "Could not copy wrapper file './$WRAPPER' to '$UVSCAN_HOME/$WRAPPER'!"
    # fi
# fi

# if [[ ! -d "$CLAMAV_HOME" ]]; then
    # Log_Print "WARNING: ClamAV home directory '$CLAMAV_HOME' does not exist.  Creating..."
    
    # if ! mkdir -p "$CLAMAV_HOME"; then
    # fi
# fi

# if [[ -f "$CLAMSCAN_BACKUP" ]]; then
    # # save file exists, bypass save
    # Log_Print "WARNING: Original ClamAV scanner executable already saved to '$CLAMSCAN_BACKUP'.  Skipping save..."
# else
    # # no existing save file, save clamscan original file
    # Log_Print "Saving original ClamAV scanner executable to '$CLAMSCAN_BACKUP'..."
    # mv "$CLAMSCAN_EXE" "$CLAMSCAN_BACKUP"
# fi

# # remove existing clamscan file or link
# Log_Print "Replacing clamscan executable with symlink to '$UVSCAN_HOME/$WRAPPER'..."
# rm -f "$CLAMSCAN_EXE"
# ln -s "$UVSCAN_HOME/$WRAPPER" "$CLAMSCAN_EXE"

# Set McAfee Custom Property #1 to '$NEW_VERSION'...
Set_CustomProp 1 "$NEW_VERSION"

# Refresh agent data with EPO
Refresh_ToEPO

# Clean up global variables and exit cleanly
unset SCRIPT_ABBR CLAMAV_HOME CLAMSCAN_EXE CLAMSCAN_BACKUP INSTALLER_ZIP DAT_ZIP INSTALL_CMD DAT_UPDATE_CMD WRAPPER DAT_UPDATE NEW_VERSION
Exit_Script 0
