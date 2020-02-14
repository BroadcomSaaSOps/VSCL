#!/bin/bash

#=============================================================================
# NAME:     VSCL-EPOPatch.sh
#-----------------------------------------------------------------------------
# Purpose:  Patch for McAfee VirusScan Command line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     13-Feb-2020
#-----------------------------------------------------------------------------
# Version:  1.25
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
# Imports:  ./VSCL-lib.sh:  library functions
#-----------------------------------------------------------------------------
# NOTES: Fixed for Commercial to not require the VSCL library
#        Fixed permissions for log file (chmod 646)
#=============================================================================


#=============================================================================
# PREPROCESS: Prevent file from being sourced
#=============================================================================
# shellcheck disable=SC2091
if $(return 0 2>/dev/null); then
    # File is  sourced, return error
    echo "VSCL EPO Patch must NOT be sourced. It must be run standalone. Aborting installer!"
    return 1
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
unset include_path this_file
declare include_path this_file
this_file="${BASH_SOURCE[0]}"
this_file=$(while [[ -L "$this_file" ]]; do this_file="$(readlink "$this_file")"; done; echo $this_file)
include_path="${this_file%/*}"
. "$include_path/VSCL-lib.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
declare -x __vscl_script_abbr="VSCLEPAT"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function install_patch {
    #----------------------------------------------------------
    # Download the latest installer from EPO and run it
    #----------------------------------------------------------
    # Params: $@ - all arguments passed to script
    #----------------------------------------------------------
    declare support_file target_file

    # Copy support files to uvscan directory
    for support_file in $__vscl_scan_support_files; do
        target_file="$__vscl_uvscan_dir/$support_file"
        log_info "Copying support file '$support_file' to '$target_file'..."

        if [[ ! -f "./$support_file" ]]; then
            # source support file not available, error
            exit_with_error "File '$support_file' not available. Aborting installer!"
        fi

        if [[ -f "$target_file" ]]; then
            # delete any existing copy of support file
            log_info "Deleting existing file '$target_file'..."
            
            if ! rm -f "$target_file"; then
                # unable to remove target file, error
                log_error "Existing file '$target_file' could not be deleted! Aborting installer!"
            fi
        fi

        if ! cp -f "./$support_file" "$__vscl_uvscan_dir"; then
            # error copying support file to target, error
            exit_with_error "Could not copy support file './$support_file' to '$__vscl_uvscan_dir/$support_file'. Aborting installer!"
        fi

        if ! chmod +x "$__vscl_uvscan_dir/$support_file"; then
            # unable to make target support file executable, error
            exit_with_error "File '$support_file' not available. Aborting installer!"
        fi
    done

    if ! chmod 646 "$__vscl_log_path"; then
        # unable to apply permissions to log file, error
        exit_with_error "Unable to set permisions on '$__vscl_log_path'. Aborting installer!"
    fi

    # Clean up global variables and exit cleanly
    exit_script $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
install_patch "$*"
