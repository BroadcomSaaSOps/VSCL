#!/bin/bash

#=============================================================================
# NAME:     update-prop1.sh
#-----------------------------------------------------------------------------
# Purpose:  Update the McAfee custom property #1 with the current 
#           version of the DAT files for the McAfee VirusScan Command line
#           Scanner 6.1.0 on SaaS Linux PPM App servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     17-JAN-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL antivirus scanner installed
#           Latest VSCL DAT .ZIP file
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#           awk, echo, cut, ls, printf
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: none
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:  library functions
#=============================================================================


#=============================================================================
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
# shellcheck disable=SC2154
if [[ -z "$__vscl_up1_loaded" ]]; then
    # not already loaded, set flag that it is now
    #echo "not loaded, loading..."
    declare -x __vscl_up1_loaded
    __vscl_up1_loaded="1"
else
    # already loaded, exit gracefully
    #echo "loaded already"
    return 0
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
. "$include_path/VSCL-lib.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
if [[ -z "$__vscl_script_abbr" ]]; then
    export -x __vscl_script_abbr="VSCL_UP1"
fi


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function update_prop1 {
    declare current_dat empty_val
    empty_val=""
    current_dat=${1:-$empty_val}
    
    if [[ -z "$current_dat" ]]; then
        # sanity checks
        # check for MACONFIG
        check_for "$__vscl_maconfig_path" "MACONFIG utility"

        # check for CMDAGENT
        check_for "$__vscl_cmdagent_path" "CMDAGENT utility"

        # check for uvscan
        if ! check_for "$__vscl_uvscan_dir/$__vscl_uvscan_exe" "uvscan executable" --no-terminate; then
            # uvscan not found
            # set custom property to error value, then exit with error
            log_info "Could not find 'uvscan executable' at '$__vscl_uvscan_dir/$__vscl_uvscan_exe'!"
            current_dat="$__vscl_notinst_code"
        else
            # Get the version of the installed DATs...
            log_info "Determining the current DAT version..."
            current_dat=$(get_curr_dat_ver)

            if [[ "$current_dat" = "$__vscl_invalid_code" ]]; then
                # Could not determine current value for DAT version from uvscan
                # set custom property to error value, then exit with error
                log_info "Unable to determine currently installed DAT version!"
                current_dat="$__vscl_invalid_code"
            else
                current_dat="VSCL:$current_dat"
            fi
            
            log_info "Current DAT Version is '$current_dat'"
        fi
    fi

    # Set custom property #1 and push to EPO, then exit cleanly
    set_custom_prop 1 "$current_dat"
    refresh_to_epo   
    return $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# shellcheck disable=SC2091
if $(return 0 2>/dev/null); then
    # File is sourced, return to sourcing code
    return 0
else
    # File is NOT sourced, execute it like it any regular shell file
    update_prop1
    
    # Clean up global variables and exit cleanly
    exit_script $?
fi
