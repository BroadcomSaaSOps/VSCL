#!/bin/bash

#=============================================================================
# NAME:     VSCL-EPOInstall.sh
#-----------------------------------------------------------------------------
# Purpose:  Installer for McAfee VirusScan Command line Scanner on 
#           FedRAMP PPM App Servers
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     18-FEB-2020
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
# Imports:  ./VSCL-Update-DAT.sh:       self-contained DAT updater
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
. "$include_path/VSCL-Update-DAT.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging
# shellcheck disable=SC2034
declare -x __vscl_script_abbr="VSCLEPOI"


#=============================================================================
# MAIN FUNCTION: primary function of this script
#=============================================================================
function install_with_epo {
    #----------------------------------------------------------
    # Download the latest installer from EPO and run it
    #----------------------------------------------------------
    # Params: $@ - all arguments passed to script
    #----------------------------------------------------------
    declare dat_update_cmd dat_update new_ver local_ver_file download_site
    declare support_file target_file

    # Command to call to download and update to current .DATs from EPO
    # shellcheck disable=SC2034
    dat_update_cmd="VSCL-Update-DAT.sh"

    # Default to updating DATs (if supplied)
    dat_update="${dat_update:-1}"

    # Default filler for Custom Property #1
    # shellcheck disable=SC2034
    # shellcheck disable=SC2154
    new_ver="$__vscl_invalid_code"

    # full path of downloaded versioning file
    # shellcheck disable=SC2154
    local_ver_file="$__vscl_temp_dir/$__vscl_pkg_ver_file"

    # download site
    # shellcheck disable=SC2154
    download_site="https://${__vscl_site_name}${__vscl_epo_server}.${__vscl_epo_domain}:443/Software/Current/$__vscl_install_pkg$__vscl_install_ver/Install/0000"

    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    unset option_var
    declare option_var

    while getopts :n option_var; do
        case "$option_var" in
            "n") dat_update=0    # do NOT update DAT files
                ;;
            *) exit_with_error "Unknown option specified. Aborting installer!"
                ;;
        esac
    done

    log_info "==========================="
    log_info "Beginning VSCL installation"
    log_info "==========================="

    # download latest installer version file from EPO "VSCL Package" directory
    if ! download_file "$download_site" "$__vscl_pkg_ver_file" "ascii" "$__vscl_temp_dir"; then
        exit_with_error "error downloading '$__vscl_pkg_ver_file' from '$download_site'. Aborting installer!"
    fi

    if [[ ! -r "$local_ver_file" ]]; then
        # unable to download version file from EPO, abort
        exit_with_error "error downloading '$__vscl_pkg_ver_file' from '$download_site'. Aborting installer!"
    fi

    # extract DAT info from avvdat.ini
    log_info "Determining the available installer version..."
    unset ini_section
    log_info "Finding section for current installer version in '$local_ver_file'..."
    # shellcheck disable=2154
    ini_section=$(find_ini_section "$__vscl_pkg_ver_section" < "$local_ver_file")

    if [[ -z "$ini_section" ]]; then
        exit_with_error "Unable to find section '$__vscl_pkg_ver_section' in '$local_ver_file'. Aborting installer!"
    fi

    declare ini_field package_name package_ver install_file

    # Parse the section and keep what we are interested in.
    for ini_field in $ini_section; do
        field_name=$(echo "$ini_field" | awk -F'=' ' { print $1 } ')
        field_value=$(echo "$ini_field" | awk -F'=' ' { print $2 } ')

        case $field_name in
            "Name") package_name="$field_value"  # name of installer
                ;; 
            "InstallVersion") package_ver="$field_value" # version of installer
                ;;
            "FileName") install_file="$field_value" # file to download
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    done

    # sanity check
    # All extracted fields have values?
    if [[ -z "$package_name" ]] || [[ -z "$package_ver" ]] || [[ -z "$install_file" ]]; then
        exit_with_error "Section '[$ini_section]' in '$local_ver_file' has incomplete data. Aborting installer!"
    fi

    log_info "New Installer Version Available: '$package_ver'"

    # Download the dat files...
    log_info "Downloading the current installer '$install_file' from '$download_site'..."

    if ! download_file "$download_site" "$install_file" "bin" "$__vscl_temp_dir"; then
        exit_with_error "Cannot download '$__vscl_temp_dir/$install_file' from '$download_site'. Aborting installer!"
    fi

    # move install files to unzip into temp
    # shellcheck disable=SC2086
    if [[ ! -f "$__vscl_temp_dir/$install_file" ]]; then
        exit_with_error "Installer archive '$__vscl_temp_dir/$install_file' does not exist. Aborting installer!"
    fi

    # untar installer archive in-place and install uvscan with default settings
    log_info "Extracting installer '$__vscl_temp_dir/$install_file' to directory '$__vscl_temp_dir'..."

    if ! cd "$__vscl_temp_dir"; then
        exit_with_error "Unable to change to temp directory '$__vscl_temp_dir'. Aborting installer!"
    fi

    if ! capture_command "tar" "-xvzf ./$install_file"; then
        exit_with_error "error extracting installer '$__vscl_temp_dir/$install_file' to directory '$__vscl_temp_dir'. Aborting installer!"
    fi

    log_info "Installing VSCL..."

    # shellcheck disable=2154
    if ! capture_command "./$__vscl_install_cmd" "-y"; then
        exit_with_error "error installing VirusScan Command line Scanner. Aborting installer!"
    fi

    if [[ "$dat_update" = "0" ]]; then
        log_info "Option specified to NOT update DAT files. Continuing..."
    else
        # OK to update DAT files
        unset err
        declare err
        update_dat
        err=$?
        
        # Run script to update DAT from EPO
        if [[ "$err" != "0" ]]; then
            exit_with_error "error updating DATs for VirusScan Command line Scanner. Aborting installer!"
        fi
        
        #new_ver=$(get_curr_dat_ver)
        #fi
    fi

    # return to original directory
    cd ..

    # Copy support files to uvscan directory
    # shellcheck disable=2154
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

    # Clean up global variables and exit cleanly
    exit_script $?
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is NOT sourced, execute like any other shell file
install_with_epo "$@"
