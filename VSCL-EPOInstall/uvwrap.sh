#!/bin/bash

#=============================================================================
# NAME:     UVWRAP.SH
#-----------------------------------------------------------------------------
# Purpose:  Wrapper to redirect PPM command line antivirus call to McAfee 
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
SCRIPT_ABBR="UVWRAP"

#=============================================================================
# MAIN
#=============================================================================
Log-Print "Beginning command line scan..."

if [[ -z "$@" ]]; then
    # exit if no file specified
    Log-Print "ERROR: No command line parameters supplied!"
    Exit_WithError 1
else
    Log-Print "Parameters supplied: '$@'"
fi

# call uvscan
if $UVSCAN_DIR/$UVSCAN_EXE -c -p --afc 512 -e --nocomp --ignore-links --noboot --nodecrypt --noexpire --one-file-system --timeout 10 "$@"; then
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

    # uvscan returned anything other than 0, exit and return 1
    Log-Print "*** Virus found! ***"
    Exit_WithError 1
fi

# No virus found, exit successfully
Log-Print "*** No virus found! ***"
Exit_Script 0
