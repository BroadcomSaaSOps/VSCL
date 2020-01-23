#!/bin/bash

#=============================================================================
# NAME:     UVWRAP.SH
#-----------------------------------------------------------------------------
# Purpose:  __VSCL_WRAPPER to redirect PPM command line antivirus call to McAfee 
#           VirusScan Command Line Scanner
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     19-Dec-2019
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL installed and integrated with PPM
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS
#-----------------------------------------------------------------------------
# Params:   $1 = full path of file to be scanned (supplied by PPM) 
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:    library functions
#=============================================================================

#-----------------------------------------
#  Imports
#-----------------------------------------
# shellcheck disable=SC1091
. ./VSCL-lib.sh

#-----------------------------------------
# Variables
#-----------------------------------------
# Abbreviation of this script name for logging
__VSCL_SCRIPT_ABBR="UVWRAP"

# Options passed to VSCL scanner
# -c                    clean viruses if found
# -p                    
# --afc 512             half-meg buffers
# -e                    
# --nocomp              don't scan compressed files
# --ignore-links        ignore symlinks
# --noboot              don't scan boot sectors
# --nodecrypt           do not decrypt files
# --noexpire            no error for expired files
# --one-file-system     do not follow mouned directory trees
# --timeout 10          scan for 10 seconds then abort
SCAN_OPTIONS="-c -p --afc 512 -e --nocomp --ignore-links --noboot --nodecrypt --noexpire --one-file-system --timeout 10"

#=============================================================================
# MAIN
#=============================================================================
Log-Print "Beginning command line scan..."

if [[ -z "$@" ]]; then
    # exit if no file specified
    Exit_WithError "No command line parameters supplied!"
else
    Log-Info "Parameters supplied: '$@'"
fi

# call uvscan
if ! Capture_Command "$__VSCL_UVSCAN_CMD" "$SCAN_OPTIONS $@"; then
    # uvscan returned error, exit and return 1
    Exit_WithError "*** Virus found! ***"
fi

# No virus found, exit successfully
Log-Info "*** No virus found! ***"
Exit_Script 0
