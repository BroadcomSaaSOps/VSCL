#!/bin/bash

#=============================================================================
# NAME:     UVWRAP.SH
#-----------------------------------------------------------------------------
# Purpose:  VSCL uvscan wrapper to redirect PPM command line antivirus call to
#           McAfee VirusScan Command line Scanner
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     17-Jun-2020
#-----------------------------------------------------------------------------
# Version:  1.25
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
# Imports:  none
#=============================================================================
# NOTES: Fixed for Commercial to not require the VSCL library
#        Fixed permissions for log file (chmod 646)
#=============================================================================

#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL uvscan wrapper must NOT be sourced.  It must be run standalone!"
    return 1
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
unset include_path this_file
declare include_path this_file

this_file="${BASH_SOURCE[0]}"

# follow symlinks until real file found
this_file=$(while [[ -L "$this_file" ]]; do this_file="$(readlink "$this_file")"; done; echo $this_file)

#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
declare -x __vscl_script_abbr="VSCLUVWR"

# Path to common log file for all VSCL scripts
declare -x __vscl_log_path="/var/McAfee/agent/logs/VSCL_mgmt.log"

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
declare -x SCAN_OPTIONS="-c -p --afc 512 -e --nocomp --ignore-links --noboot --nodecrypt --noexpire --one-file-system --timeout 10"

#=============================================================================
# FUNCTIONS: VSCL Library functions
#=============================================================================

function log_print {
    #----------------------------------------------------------
    # Print a message to the log defined in $__vscl_log_path
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    # replaces same function from VSCL library
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    declare out_text

    # Prepend date/time, which script, then the log message
    # i.e.  "11/12/2019 11:14:10 AM:VSCL_UP1:[x]Refreshing agent data with EPO..."
    #        <- date -------------> <script> <+><-- message -->
    #                                         ^-- log mode "I": info, "W": warning, "E": errror
    out_text="$(date +'%x %X'):$__vscl_script_abbr:$*"

    if [[ -w $__vscl_log_path ]]; then
        # log file exists and is writable, append
        printf "%s\n" "$out_text" | tee --append "$__vscl_log_path"
    else
        # log file absent, create
        printf "%s\n" "$out_text" | tee "$__vscl_log_path"
    fi

    return 0
}

#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
log_print "=============================="
log_print "Beginning command line scan..."
log_print "=============================="

if [[ -z "$*" ]]; then
    # exit if no file specified
    log_print "[E]No command line parameters supplied!"
    exit 1
else
    log_print "Parameters supplied: '$*'"
fi

# call uvscan
if ! /usr/local/uvscan/uvscan $scan_options $*; then
    # uvscan returned error, exit and return 1
    log_print "[E]*** Virus found! ***"
    exit 1
fi

# No virus found, exit successfully
log_print "[I]*** No virus found! ***"
exit 0
 