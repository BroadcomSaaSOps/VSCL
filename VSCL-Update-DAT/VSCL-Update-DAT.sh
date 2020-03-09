#!/bin/bash

#=============================================================================
# Name:     VSCL-Update-DAT.sh
#-----------------------------------------------------------------------------
# Purpose:  Update the DAT files for the McAfee VirusScan Command line
#           Scanner 6.1.3 on SaaS Linux PPM App servers from EPO
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     18-FEB-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL antivirus already scanner installed to /usr/local/uvscan
#           Latest VSCL DAT .ZIP file available via EPO
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#           awk, echo, cut, ls, printf, wget or curl
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: -d:  download current DATs and exit
#           -l:  leave any files extracted intact at exit
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-Update-Prop1.sh: self-contained Custom Prop #1 updater
#=============================================================================

#=============================================================================
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
if [[ -z "$__vscl_udd_loaded" ]]; then
    declare -x __vscl_udd_loaded
    __vscl_udd_loaded="1"
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
. "$include_path/VSCL-Update-Prop1.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging, NOT set if sourced
# shellcheck disable=2034
if [[ -z "$__vscl_script_abbr" ]]; then
    declare -x __vscl_script_abbr
    __vscl_script_abbr="VCSLUDAT"
fi


#=============================================================================
# FUNCTION: primary function of script
#=============================================================================
function update_dat () {
    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    # shellcheck disable=2034
    declare option_var download_only
    declare -x __vscl_leave_files
    
    download_only=""
    __vscl_leave_files=""

    while getopts :dl option_var; do
        case "$option_var" in
            "d") download_only="1"    # only download most current DAT from EPO and exit
                ;;
            "l") __vscl_leave_files="1"      # leave any temp files on exit
                ;;
            *) exit_with_error "Unknown option specified!"
                ;;
        esac
    done

    shift "$((OPTIND-1))"

    #-----------------------------------------
    # Local variables
    #-----------------------------------------
    # Name of the file in the repository to extract current DAT version from
    declare local_ver_file
    # shellcheck disable=2154
    local_ver_file="$__vscl_temp_dir/$__vscl_epo_ver_file"

    # download site
    declare dat_dl_site
    # shellcheck disable=2154
    dat_dl_site="https://${__vscl_site_name}${__vscl_epo_server}.${__vscl_epo_domain}:443/Software/Current/VSCANDAT1000/DAT/0000"


    #-----------------------------------------
    #  Main code of DAT update function
    #-----------------------------------------
    log_info "==========================="
    log_info "Beginning VSCL DAT update"
    log_info "==========================="

    if [[ -z "$download_only" ]]; then
        # check for MACONFIG
        # shellcheck disable=2154
        check_for "$__vscl_maconfig_path" "McAfee EPO Agent MACONFIG utility"

        # check for CMDAGENT
        # shellcheck disable=2154
        check_for "$__vscl_cmdagent_path" "McAfee EPO Agent CMDAGENT utility"

        # check for uvscan
        # shellcheck disable=2154
        if ! check_for "$__vscl_uvscan_dir/$__vscl_uvscan_exe" "uvscan executable" --no-terminate > /dev/null 2>&1; then
            # uvscan not found
            # set custom property to error value, then exit
            log_info "Setting McAfee Custom Property #1 to '$__vscl_notinst_code'..."
            set_custom_prop 1 "$__vscl_notinst_code"
            refresh_to_epo
            exit_with_error "Cannot update DATs, VSCL not installed!"
        fi
    fi

    # # make temp dir if it doesn't exist
    # log_info "Checking for temporary directory '$__vscl_temp_dir'..."

    # if [[ ! -d "$__vscl_temp_dir" ]]; then
        # log_info "Creating temporary directory '$__vscl_temp_dir'..."

        # if ! mkdir -p "$__vscl_temp_dir" > /dev/null 2>&1; then
            # exit_with_error "error creating temporary directory '$__vscl_temp_dir'!"
        # fi
    # fi

    # if [[ ! -d "$__vscl_temp_dir" ]]; then
        # exit_with_error "error creating temporary directory '$__vscl_temp_dir'!"
    # fi

    # download current DAT version file from repository, exit if not available
    log_info "Downloading DAT versioning file '$__vscl_epo_ver_file' from '$dat_dl_site'..."

    #download_out="$?"

    if ! download_file "$dat_dl_site" "$__vscl_epo_ver_file" "ascii" "$__vscl_temp_dir"; then
        exit_with_error "Error downloading '$__vscl_epo_ver_file' from '$dat_dl_site'!"
    fi

    # Did we get the version file?
    if [[ ! -r "$local_ver_file" ]]; then
        exit_with_error "Error downloading '$__vscl_epo_ver_file' from '$dat_dl_site'!"
    fi

    if [[ -z "$download_only" ]]; then
        # Get the version of the installed DATs...
        log_info "Determining the currently installed DAT version..."

        unset curr_dat curr_major curr_minor
        declare curr_dat curr_major curr_minor
        curr_dat=$(get_curr_dat_ver)

        if [[ -z "$curr_dat" ]] ; then
            log_info "Unable to determine currently installed DAT version!"
            curr_dat="0000.0"
        else
            # extract major version, minor is always "0" for current engine/DATs
            curr_major="$(echo "$curr_dat" | cut -d. -f-1)"
            curr_minor="0"
        fi
    fi
    
    # extract DAT info from avvdat.ini
    log_info "Determining the available DAT version..."
    declare ini_section
    ini_section=""
    log_info "Finding section for current DAT version in '$local_ver_file'..."
    log_info "\$__vscl_epo_ver_section = '$__vscl_epo_ver_section'"
    log_info "\$ini_section = '$ini_section'"
    # shellcheck disable=2154
    ini_section=$(find_ini_section "$__vscl_epo_ver_section" < "$local_ver_file")
    log_info "After \$__vscl_epo_ver_section = '$__vscl_epo_ver_section'"
    log_info "After \$ini_section = '$ini_section'"

    if [[ -z "$ini_section" ]]; then
        exit_with_error "Unable to find section '$__vscl_epo_ver_section' in '$local_ver_file'!"
    fi

    declare ini_field avail_major avail_minor file_name file_path file_size md5_sum
    declare field_name field_value perform_update download_out dat_zip validate_out
    declare update_out new_ver new_major new_minor
    
    # Some INI sections have the MinorVersion field missing.
    # To work around this, we will initialise it to 0.
    avail_minor=0
    avail_major=0
    file_name=""
    file_path=""
    file_size=0
    md5_sum=""

    # Parse the section and keep what we are interested in.
    for ini_field in $ini_section; do
        field_name=$(echo "$ini_field" | awk -F'=' ' { print $1 } ')
        field_value=$(echo "$ini_field" | awk -F'=' ' { print $2 } ')

        case ${field_name,,} in
            "datversion") avail_major="$field_value"  # available: major
                ;; 
            "minorversion") avail_minor="$field_value" # available: minor
                ;;
            "filename") file_name="$field_value" # file to download
                ;;
            "filepath") file_path="$field_value" # path on FTP server
                ;;
            "filesize") file_size="$field_value" # file size
                ;;
            "md5") md5_sum="$field_value" # md5_sum checksum
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    done

    log_info "\$avail_major = '$avail_major'"
    log_info "\$avail_minor = '$avail_minor'"
    log_info "\$file_name = '$file_name'"
    log_info "\$file_path = '$file_path'"
    log_info "\$file_size = '$file_size'"
    log_info "\$md5_sum = '$md5_sum'"

    # sanity check
    # All extracted fields have values?
    if [[ -z "$avail_major" ]] || [[ -z "$avail_minor" ]] || [[ -z "$file_name" ]] || [[ -z "$file_path" ]] || [[ -z "$file_size" ]] || [[ -z "$md5_sum" ]]; then
        exit_with_error "Section '[$__vscl_epo_ver_section]' in '$local_ver_file' has incomplete data!"
    fi

    # shellcheck disable=2154
    if [[ "$curr_dat" = "$__vscl_invalid_code" ]]; then
        log_info "Current DAT Version not available/invalid"
    else
        log_info "Current DAT Version: '$curr_major.$curr_minor'"
    fi
    
    log_info "New DAT Version Available: '$avail_major.$avail_minor'"

    if [[ -z "$download_only" ]]; then
        # shellcheck disable=2154
        if [[ "$curr_major" = "$__vscl_invalid_code" ]]; then
            perform_update="yes";
        # Installed version is less than current DAT version?
        elif (( curr_major < avail_major )) || ( (( curr_major == avail_major )) && (( curr_minor < avail_minor )) ); then
            perform_update="yes"
        fi
    fi

    # OK to perform update?
    if [[ -n "$perform_update" ]] || [[ -n "$download_only" ]]; then
        if [[ -n "$perform_update" ]]; then
            log_info "Performing an update ($curr_dat -> $avail_major.$avail_minor)..."
        fi

        # Download the dat files...
        log_info "Downloading the current DAT '$file_name' from '$dat_dl_site'..."

        download_file "$dat_dl_site" "$file_name" "bin" "$__vscl_temp_dir"
        download_out="$?"

        if [[ "$download_out" != "0" ]]; then
            exit_with_error "error downloading '$file_name' from '$dat_dl_site'!"
        fi

        dat_zip="$__vscl_temp_dir/$file_name"

        # Did we get the dat update file?
        if [[ ! -r "$dat_zip" ]]; then
            exit_with_error "Unable to download DAT file '$dat_zip'!"
        fi

        validate_file "$dat_zip" "$file_size" "$md5_sum"
        validate_out="$?"

        if [[ "$validate_out" != "0" ]]; then
            exit_with_error "DAT download failed - Validation failed for '$__vscl_temp_dir/$file_name'!"
        fi

        # Exit if we only wanted to download
        if [[ -n "$download_only" ]]; then
            # shellcheck disable=2154
            log_info "DAT downloaded to '$dat_zip'.  Exiting.."
            exit_script 0
        fi

        # shellcheck disable=2154
        update_from_zip "$__vscl_uvscan_dir" "$dat_zip" "$__vscl_epo_file_list"
        update_out="$?"

        if [[ "$update_out" != "0" ]] ; then
            exit_with_error "error unzipping DATs from file '$__vscl_temp_dir/$__vscl_dat_zip'!"
        fi

        # Check the new version matches the downloaded one.
        log_info "Starting up uvscan with new DAT files..."
        new_ver=$(get_curr_dat_ver)

        if [[ -z "$new_ver" ]]; then
            # Could not determine current value for DAT version from uvscan
            # set custom property to error value, then exit with error
            log_info "Unable to determine currently installed DAT version!"
            new_ver="$__vscl_invalid_code"
        else
            log_info "Checking that the installed DAT matches the available DAT version..."
            new_major=$(get_curr_dat_ver "DATMAJ")
            new_minor=$(get_curr_dat_ver "DATMIN")

            if (( new_major != avail_major )) || (( new_minor != avail_minor )); then
                exit_with_error "DAT update failed - installed version different than expected!"
            else
                log_info "DAT update succeeded ($curr_dat -> $new_ver)!"
            fi

            new_ver="VSCL:$new_ver"
        fi

        # Set McAfee Custom Property #1 to '$new_ver'...
        update_prop1
        return $?
    else
        if [[ -z "$perform_update" ]]; then
            log_info "Installed DAT is already up to date ($curr_dat)!  Exiting..."
        fi
    fi

    return 0
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# shellcheck disable=2091
if $(return 0 2>/dev/null); then
    # File is sourced, return to sourcing code
    log_info "VSCL Update DAT functions loaded successfully!"
    return 0
else
    # File is NOT sourced, execute it like it any regular shell file
    update_dat "$@"
    
    # Clean up global variables and exit cleanly
    exit_script $?
fi
