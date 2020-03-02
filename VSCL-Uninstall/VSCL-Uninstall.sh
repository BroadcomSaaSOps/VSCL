#!/bin/bash

#=============================================================================
# NAME:     UNINSTALL-VSCL.SH
#-----------------------------------------------------------------------------
# Purpose:  Uninstall the McAfee VirusScan Command line Scanner v6.1.0
#           from SaaS Linux PPM App servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     18-FEB-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           PPM Application Server
#           VSCL installed
#           unzip, tar, gunzip, gclib (> 2.7) utilities in OS
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:              library functions
#           ./VSCL-Update-Prop1.sh:     self-contained Custom Prop #1 updater
#=============================================================================


#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
# shellcheck disable=2091
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Uninstaller must NOT be sourced.  It must be run standalone!"
    return
fi


#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
unset include_path this_file
declare include_path this_file

# get this script's filename from bash
this_file="${BASH_SOURCE[0]}"
# bash_source does NOT follow symlinks, traverse them until we get a real file
this_file=$(while [[ -L "$this_file" ]]; do 
                this_file="$(readlink "$this_file")";
                done; 
                echo "$this_file")
# extract path to this script
include_path="${this_file%/*}"
# shellcheck disable=SC1090
. "$include_path/VSCL-Update-Prop1.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
declare -x __vscl_script_abbr="VSCLUNIN"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function uninstall_vscl {
    log_info "==========================="
    log_info "Beginning VSCL uninstall"
    log_info "==========================="

    #echo "\$__vscl_uvscan_dir = '$__vscl_uvscan_dir'"

    # uninstall the uvscan product and remove the uninstaller
    # shellcheck disable=2154
    if [ ! -d "$__vscl_uvscan_dir" ]; then
        exit_with_error "VSCL software directory not found in '$__vscl_uvscan_dir'!"
    fi

    log_info "Running VSCL uninstaller..."

    # shellcheck disable=2154
    if capture_command "$__vscl_uninstall_cmd" "" "/usr/bin/yes"; then
        #echo "\$__vscl_uvscan_dir = '$__vscl_uvscan_dir'"
        if ! rm -rf "$__vscl_uvscan_dir" &> /dev/null; then
            log_warning "Unable to remove VSCL software directory '$__vscl_uvscan_dir'!"
        fi
    else
        exit_with_error "Unable to uninstall VSCL software!"
    fi

    # Update the first custom property
    update_prop1

    # Clean up global variables and exit cleanly
    exit_script $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
uninstall_vscl
