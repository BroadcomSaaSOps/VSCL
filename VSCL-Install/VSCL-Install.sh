#!/bin/bash

#=============================================================================
# NAME:     VSCL-Install.sh
#-----------------------------------------------------------------------------
# Purpose:  Installer for McAfee VirusScan Command Line Scanner 6.1.3 on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     21-OCT-2019
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
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-local.sh
#============================================================================= 

#=============================================================================
# VARIABLES
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
. ./VSCL-local.sh

#-----------------------------------------
# Globals
# (these variables are normally best left unmodified)
#-----------------------------------------
# place where VSCL installer will live on PPM server
UVSCAN_HOME="/usr/local/uvscan"
# Temporary directory for use while installing
TEMP_DIR="VSCL-TEMP"
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
# Path to default log file
LOG_PATH="/var/McAfee/agent/logs/VSCL_mgmt.log"
# Filename of scan wrapper to put in place of ClamAV executable
WRAPPER="uvwrap.sh"
SCRIPT_ABBR="VSCLINST"

#=============================================================================
# FUNCTIONS
#=============================================================================

Log-Print() {
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    local OUTPUT
    OUTPUT="$(date +'%x %X'):$SCRIPT_ABBR:$*"

    if [[ -f "$LOGPATH" ]]; then
        echo "$OUTPUT" | tee --append "$LOG_PATH"
    else
        echo "$OUTPUT" | tee "$LOG_PATH"
    fi
    
    return 0
}

function Exit-Script {
    #----------------------------------------------------------
    # Params: $1 = exit code (assumes 0/ok)
    #----------------------------------------------------------

    local OUTCODE

    Log-Print "==========================="

    if [ -z "$1" ]; then
        OUTCODE="0"
    else
        if [ "$1" != "0" ]; then
            OUTCODE="$1"
        fi
    fi
    
    Log-Print "Ending with exit code: $1"
    Log-Print "==========================="
    exit $OUTCODE
}

function Exit-WithError() {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
    # Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [ -n "$1" ]; then
        Log-Print "$1"
    fi

    Exit-Script 1
}

#=============================================================================
# MAIN
#=============================================================================

Log-Print "==========================="
Log-Print "Beginning VSCL installation"
Log-Print "==========================="

# make temp directory off installer directory
if [ ! -d "./$TEMP_DIR" ]; then 
  Log-Print "Creating temp directory '$TEMP_DIR'..."
  mkdir -p "./$TEMP_DIR"
fi

# move install files to unzip into temp
# >>> DO NOT add quote below, [ -f ] conditionals don't work with quoting
if [ -f ./$INSTALLER_ZIP ]; then
    Log-Print "Copying install archive to temp directory..."
    cp -f ./$INSTALLER_ZIP "./$TEMP_DIR"
else 
    Exit-WithError "ERROR: Installer archive './$INSTALLER_ZIP' does not exist!"
fi

#TODO: Download installer from EPO

# untar installer archive in-place and install uvscan with default settings
Log-Print "Extracting installer to directory './$TEMP_DIR'..."
cd "./$TEMP_DIR"

if ! tar -xvzf ./$INSTALLER_ZIP; then
    Exit-WithError "Error extracting installer to directory './$TEMP_DIR'!"
fi

Log-Print "Installing VSCL..."
if ! "./$INSTALL_CMD" -y; then
    Exit-WithError "Error installing VirusScan Command Line Scanner!"
fi

# remove temp directory
Log-Print "Removing temp directory..."
cd ..
rm -rf "./$TEMP_DIR"

#TODO: Download latest DATs from EPO

# Run shell file to update the scanner with the latest AV definitions
if [ -f "./$DAT_ZIP" ]
then
    Log-Print "Unpacking DAT files to uvscan directory..."
    "./$DAT_UPDATE_CMD" "./$DAT_ZIP"
else
    Log-Print "WARNING: .DAT files unavailable for installation!"
fi

if [ -f "./$WRAPPER" ]; then
    # make uvwrap.sh executable and copy to uvscan directory
    Log-Print "Setting up shim wrapper for uvscan..."
    chmod +x "./$WRAPPER"
else
    Exit-WithError "File '$WRAPPER' not available.  Aborting installer!"
fi

if [ -f "$UVSCAN_HOME/$WRAPPER" ]; then
    rm -f "$UVSCAN_HOME/$WRAPPER"
fi

cp -f "./$WRAPPER" "$UVSCAN_HOME"

if [ ! -d "$CLAMAV_HOME" ]; then
    Log-Print "WARNING: ClamAV home directory '$CLAMAV_HOME' does not exist.  Creating..."
    mkdir -p "$CLAMAV_HOME"
fi

if [ -f "$CLAMSCAN_BACKUP" ]; then
    # save file exists, bypass save
    Log-Print "WARNING: Original ClamAV scanner executable already saved to '$CLAMSCAN_BACKUP'.  Skipping save..."
else
    # no existing save file, save clamscan original file
    Log-Print "Saving original ClamAV scanner executable to '$CLAMSCAN_BACKUP'..."
    mv "$CLAMSCAN_EXE" "$CLAMSCAN_BACKUP"
fi

# remove existing clamscan file or link
Log-Print "Replacing clamscan executable with symlink to '$UVSCAN_HOME/$WRAPPER'..."
rm -f "$CLAMSCAN_EXE"
ln -s "$UVSCAN_HOME/$WRAPPER" "$CLAMSCAN_EXE"

Exit-Script 0

