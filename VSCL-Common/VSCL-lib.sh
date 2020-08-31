#!/bin/bash

#=============================================================================
# NAME:         VSCL-lib.sh
#-----------------------------------------------------------------------------
# Purpose:      Shared code for VSCL management scripts
#-----------------------------------------------------------------------------
# Creator:      Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:         18-FEB-2020
#-----------------------------------------------------------------------------
# Version:      1.2
#-----------------------------------------------------------------------------
# PreReqs:      none
#-----------------------------------------------------------------------------  
# Switches:     -f: force library to load even if already loaded
#-----------------------------------------------------------------------------  
# Imports:      ./VSCL-local.sh:    local per-site variables
#=============================================================================


#=============================================================================
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
# If this file is NOT sourced, return error
# shellcheck disable=2091
if ! $(return 0 2>/dev/null); then
    echo ">> ERROR! VSCL Library must be sourced.  It cannot be run standalone!"
    exit 1
fi

# Bypass inclusion if already loaded
if [[ -z "$__vscl_lib_loaded" ]]; then
    # not already loaded, set flag that it is now
    #echo "not loaded, loading..."
    declare -x __vscl_lib_loaded
    __vscl_lib_loaded="1"
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
. "$include_path/VSCL-local.sh"


#=============================================================================
# GLOBALS: Global variables used by all scripts that import this library
#=============================================================================
unset __vscl_script_abbr __vscl_script_name __vscl_script_path __vscl_debug_it
unset __vscl_leave_files __vscl_log_path __vscl_uvscan_exe __vscl_uninstall_exe 
unset __vscl_uvscan_dir __vscl_uvscan_cmd __vscl_install_cmd __vscl_uninstall_cmd 
unset __vscl_wrapper __vscl_library __vscl_localize __vscl_maconfig_path 
unset __vscl_cmdagent_path __vscl_install_pkg __vscl_install_ver __vscl_pkg_ver_file 
unset __vscl_pkg_ver_section __vscl_epo_ver_file __vscl_epo_ver_section 
unset __vscl_epo_file_list __vscl_scan_support_files __vscl_mask_regexp 
unset __vscl_notinst_code __vscl_invalid_code __vscl_temp_dir __vscl_temp_file

declare -x  __vscl_script_abbr __vscl_script_name __vscl_script_path __vscl_debug_it
declare -x  __vscl_leave_files __vscl_log_path __vscl_uvscan_exe __vscl_uninstall_exe 
declare -x  __vscl_uvscan_dir __vscl_uvscan_cmd __vscl_install_cmd __vscl_uninstall_cmd 
declare -x  __vscl_wrapper __vscl_library __vscl_localize __vscl_maconfig_path 
declare -x  __vscl_cmdagent_path __vscl_install_pkg __vscl_install_ver __vscl_pkg_ver_file 
declare -x  __vscl_pkg_ver_section __vscl_epo_ver_file __vscl_epo_ver_section 
declare -x  __vscl_epo_file_list __vscl_scan_support_files __vscl_mask_regexp 
declare -x  __vscl_notinst_code __vscl_invalid_code __vscl_temp_dir __vscl_temp_file

# name of script file (the one that dotsourced this library, not the library itself)
# shellcheck disable=SC2034
__vscl_script_name="$this_file"

# path to script file (the one that dotsourced this library, not the library itself)
__vscl_script_path="$include_path"

# show debug messages (set to non-empty to enable)
__vscl_debug_it=""

# flag to erase any temp files on exit (set to non-empty to enable)
__vscl_leave_files=""

# Path to common log file for all VSCL scripts
__vscl_log_path="/var/McAfee/agent/logs/VSCL_mgmt.log"

# name of VSCL scanner executable
__vscl_uvscan_exe="uvscan"

# name of VSCL scanner uninstaller
__vscl_uninstall_exe="uninstall-uvscan"

# __vscl_uvscan_dir must be a directory and writable where VSCL is installed
__vscl_uvscan_dir="/usr/local/uvscan"

# full path to uvscan executable
__vscl_uvscan_cmd="$__vscl_uvscan_dir/$__vscl_uvscan_exe"

# Raw command to install VSCL from installer tarball
# shellcheck disable=SC2034
__vscl_install_cmd="install-uvscan"

# Raw command to remove VSCL from system
# shellcheck disable=SC2034
__vscl_uninstall_cmd="$__vscl_uvscan_dir/$__vscl_uninstall_exe"

# Filename of scan wrapper to copy to VSCL software directory
__vscl_wrapper="uvwrap.sh"

# Filename of VSCL library to copy to VSCL software directory (i.e. this file)
__vscl_library="VSCL-lib.sh"

# Filename for site localization
__vscl_localize="VSCL-local.sh"

# path to MACONFIG program
__vscl_maconfig_path="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
__vscl_cmdagent_path="/opt/McAfee/agent/bin/cmdagent"

# EPO package name of uploaded VSCL installer
# shellcheck disable=SC2034
__vscl_install_pkg="VSCLPACK"

# Version of EPO package name of uploaded VSCL installer
# shellcheck disable=SC2034
__vscl_install_ver="6140"

# Name of versioning file in EPO installer package
# shellcheck disable=SC2034
__vscl_pkg_ver_file="vsclpackage.ini"

# Section name of versioning file to search for
# shellcheck disable=SC2034
__vscl_pkg_ver_section="VSCL-PACK"

# name of the repo file with current DAT version
# shellcheck disable=SC2034
__vscl_epo_ver_file="avvdat.ini"

# section of avvdat.ini from repository to examine for DAT version
# shellcheck disable=SC2034
__vscl_epo_ver_section="AVV-ZIP"

# space-delimited list of files to unzip from downloaded EPO .ZIP file
# format => <filename>:<permissions>
# shellcheck disable=SC2034
__vscl_epo_file_list="avvscan.dat:444 avvnames.dat:444 avvclean.dat:444"

# space-delimited list of files to unzip from downloaded EPO .ZIP file
# format => <filename>:<permissions>
# shellcheck disable=SC2034
__vscl_scan_support_files="$__vscl_wrapper $__vscl_library $__vscl_localize"

# sed style mask to remove common text in McAfee error messages
# example "2020-01-25 14:22:44.456234 (2010.2739) maconfig.Info: configuration finished"
# will be logged as  ">> maconfig.Info: configuration finished"
__vscl_mask_regexp="s/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*\ ([0-9]*\.[0-9]*)\ //g"

# default return codes for Custom 1 property fields
# shellcheck disable=SC2034
__vscl_notinst_code="VSCL:NOT_INSTALLED"
__vscl_invalid_code="VSCL:INVALID_DAT"


#=============================================================================
# FUNCTIONS: VSCL Library functions
#=============================================================================

function do_cleanup {
    #------------------------------------------------------------
    # If '__vscl_leave_files' global is NOT set, erase downloaded files
    # before exiting
    #------------------------------------------------------------

    # shellcheck disable=2154
    if [[ -z "$__vscl_leave_files" ]]; then
        if [[ -d "$__vscl_temp_dir" ]]; then
            # log_info "Removing temp dir '$__vscl_temp_dir'..."
            
            if ! rm -rf "$__vscl_temp_dir"; then
                log_warning "Cannot remove temp dir '$__vscl_temp_dir'!"
            fi

            # log_info "Removing temp file '$__vscl_temp_file'..."
            
            if ! rm -rf "$__vscl_temp_file"; then
                log_warning "Cannot remove temp file '$__vscl_temp_file'!"
            fi
        fi
    else
        log_info "'LEAVE FILES' option specified.  NOT deleting temp dir '$__vscl_temp_dir' or file '$__vscl_temp_file'!"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function exit_script {
    #----------------------------------------------------------
    # Exit the script with an exit code
    #----------------------------------------------------------
    # Params: $1 = exit code (assumes 0/ok)
    #----------------------------------------------------------

    declare out_code
    out_code="${1:-0}"
    
    log_info "==========================="
    log_info "Ending with exit code '$1'"
    log_info "==========================="

    # Clean up temp files
    do_cleanup

    case "$-" in
        # do a simple RETURN if invoked from the command line
        *i*) return "$out_code"
            ;;
        # otherwise exit the script
        *) exit  "$out_code"
            ;;
    esac
}

#-----------------------------------------------------------------------------

function exit_with_error {
    #----------------------------------------------------------
    # Exit script with error code 1
    #----------------------------------------------------------
    # Params: $1 (optional) error message to print
    #----------------------------------------------------------

    if [[ -n "$1" ]]; then
        log_error "$1"
    fi

    exit_script 1
}

#-----------------------------------------------------------------------------

function log_print {
    #----------------------------------------------------------
    # Print a message to the log defined in $__vscl_log_path
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    declare out_text save_opts
    
    # turn off logging for this function, if it is on
    save_opts=$SHELLOPTS
    set +x
    
    # Prepend date/time, which script, then the log message
    # i.e.  "11/12/2019 11:14:10 AM:VSCL_UP1:[x]Refreshing agent data with EPO..."
    #        <- date -------------> <script> <+><-- message -->
    #                                         ^-- log mode "I": info, "W": warning, "E": error
    out_text="$(date +'%x %X'):$__vscl_script_abbr:${LINENO}:$*"

    if [[ -w $__vscl_log_path ]]; then
        # log file exists and is writable, append
        #echo -e "$out_text" | tee --append "$__vscl_log_path"
        printf "%s\n" "$out_text" | tee --append "$__vscl_log_path"
    else
        # log file absent, create
        #echo -e "$out_text" | tee "$__vscl_log_path"
        printf "%s\n" "$out_text" | tee "$__vscl_log_path"
    fi
    
    # turn off logging back on this function, if it was on before
    if [[ "$save_opts" == *"xtrace"* ]]; then
        set -x
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function log_info {
    #----------------------------------------------------------
    # Print a INFO MESSAGE to the log defined in $__vscl_log_path
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = info message to print
    #----------------------------------------------------------

    # Prepend info marker and print
    log_print "[I]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function log_warning {
    #----------------------------------------------------------
    # Print a WARNING to the log defined in $__vscl_log_path
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = warning message to print
    #----------------------------------------------------------

    # Prepend warning marker and print
    log_print "[W]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function log_error {
    #----------------------------------------------------------
    # Print an error to the log defined in $__vscl_log_path
    # (by default '/var/McAfee/agent/logs/VSCL_mgmt.log')
    #----------------------------------------------------------
    # Params: $1 = error message to print
    #----------------------------------------------------------

    # Prepend error marker and print
    log_print "[E]:$*"
    return 0
}

#-----------------------------------------------------------------------------

function capture_command {
    #------------------------------------------------------------
    # Function to capture output of command to log
    #------------------------------------------------------------
    # Params: $1 = command to capture
    #         $2 = arguments of command
    #         $3 = command to run and pipe into captured command
    #------------------------------------------------------------
    # Returns: 0/ok if command ran
    #          error code if command failed
    #------------------------------------------------------------
    declare capture_err out_text capture_cmd capture_arg var_empty
    declare out_array pre_cmd
    
    # massage inputs
    var_empty=""
    capture_cmd="${1:-$var_empty}"
    capture_arg="${2:-$var_empty}"
    pre_cmd="${3:-$var_empty}"

    # Error if not capture command supplied
    if [[ -z "$capture_cmd" ]]; then
        exit_with_error "Command to capture empty!"
    fi

    if [[ -n "$pre_cmd" ]]; then
        # "Pre" command supplied, log it
        log_info ">> cmd = '$pre_cmd | $capture_cmd $capture_arg > $__vscl_temp_file 2>&1'"
    else
        # Log command to capture
        log_info ">> cmd = '$capture_cmd $capture_arg > $__vscl_temp_file 2>&1'"
    fi
    
    #log_info "\$__vscl_temp_file = '$__vscl_temp_file'"
    
    # capture command (and any "pre" command) to a temp file
    # shellcheck disable=SC2086
    if [[ -n "$pre_cmd" ]]; then
        # "Pre" command supplied, pipe it into the command to capture
        $pre_cmd | $capture_cmd $capture_arg > "$__vscl_temp_file" 2>&1
    else
        $capture_cmd $capture_arg > "$__vscl_temp_file" 2>&1
    fi
    
    capture_err=$?
    IFS=$__vscl_save_ifs
    out_array=()
    
    # get output from temp file, split lines into an array
    IFS=$'\n' read -r -d '' -a out_array < <( cat "$__vscl_temp_file" && printf '\0' )

    for out_text in "${out_array[@]}"; do
        # loop through each line of out_text
        # append out_text to log
        if [[ -n "$__vscl_mask_regexp" ]]; then
            # mask supplied, apply to each line
            out_text=$(printf "%s\n" "$out_text" | sed -e "$__vscl_mask_regexp")
        fi
        
        log_info ">> $out_text"
    done
   
    if [ $capture_err -ne 0 ]; then
        # error running command, return error code
        return $capture_err
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function refresh_to_epo {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------
    declare cmdagent_flags flag_name

    # flags to use with CMDAGENT utility
    cmdagent_flags="-c -f -p -e"
    log_info "Refreshing agent data to EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for flag_name in $cmdagent_flags; do
        if ! capture_command "$__vscl_cmdagent_path" "$flag_name"; then
            log_error "Unable to run EPO refresh command '$__vscl_cmdagent_path $flag_name'\!"
        fi
    done
    
    return 0
}

#-----------------------------------------------------------------------------

function find_ini_section {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Returns: space-delimited INI entries in specified 
    #          section to to STDOUT
    #          exit code = 0 if section found
    #          exit code = 1 if section NOT found
    #----------------------------------------------------------

    declare in_section section_found section_name line

    # massasge the section name to look for, default to "[default]"
    section_name="[${1:-default}]"

    # Read each line of the file
    while read -rs line; do
        if [[ "$line" = "$section_name" ]]; then
            # Section header found, go to next line
            section_found=1
            in_section=1
        elif [[ -n "$in_section" ]]; then
            # In correct section
            if [[ "$(echo "$line" | cut -c1)" != "[" ]]; then
                # not a section header
                if [[ -n "$line" ]]; then
                    # line not empty, append to STDOUT
                    printf "%s\n" "$line"
                fi
            else
                # reached next section
                unset in_section
            fi
        fi
    done
    
    if [[ -n "$section_found" ]]; then
        # section found, return ok, contents of INI section on stdout
        return 0
    else
        # section not found, return error, stdout blank
        log_error "Section '$1' not found in INI file!"
        return 1
    fi
}

#-----------------------------------------------------------------------------

function check_for {
    #------------------------------------------------------------
    # Function to check that a file is available and executable
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) "--no-terminate" to return always
    #------------------------------------------------------------
    log_info "Checking for '$2' at '$1'..."

    if [[ ! -x "$1" ]]; then
        # not available or executable
        if [[ "$3" = "--no-terminate" ]]; then
            # return error but do not exit script
            log_error "Could not find file '$2' at '$1'!"
            return 1
        else
            # exit script with error
            exit_with_error "Could not find file '$2' at '$1'!"
        fi
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function set_custom_prop {
    #------------------------------------------------------------
    # Set the value of a McAfee custom property
    #------------------------------------------------------------
    # Params: $1 = number of property to set (1-8) 
    #         $2 = value to set property
    #------------------------------------------------------------
    declare new_label ma_options
    
    # replace any spaces in input with "_"
    new_label="${2/ /_}"
    
    ma_options=("-custom"  "-prop$1" "$new_label")
    
    log_info "Setting EPO Custom Property #$1 to '$2'..."
    
    if ! capture_command "$__vscl_maconfig_path" "${ma_options[*]}"; then
        return 1
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function get_curr_dat_ver {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------
    # Params: $1 = which part to return
    #              <blank>: Entire DAT and engine string (default)
    #              DATMAJ:  DAT file major version #
    #              DATMIN:  DAT file minor version # (always zero)
    #              ENGMAJ:  Engine major version #
    #              ENGMIN:  Engine minor version #
    #              EXEVER:  Executable version string
    #------------------------------------------------------------
    # Output: null if error, otherwise number according to
    #         value of $1 (see above), default entire DAT and 
    #         engine string
    #----------------------------------------------------------

    declare uvscan_status local_dat_ver local_eng_ver out_text
    declare cmd_result local_exe_ver

    # uvscan command not available/not installed exit with error
    if ! check_for "$__vscl_uvscan_cmd" "uvscan executable" > /dev/null 2>&1 ; then
        printf "%s\n" "$__vscl_invalid_code"
        return 1
    fi
    
    # capture "uvscan --version" output, should look like this example:
    #
    #     McAfee VirusScan Command Line for Linux64 Version: 6.1.3.242
    #     Copyright (C) 2019 McAfee, Inc.
    #     (408) 988-3832 LICENSED COPY - February 06 2020
    #     
    #     AV Engine version: 6010.8670 for Linux64.
    #     Dat set version: 9523 created Feb 6 2020
    #     Scanning for 668685 viruses, trojans and variants.
    #

    cmd_result=$("$__vscl_uvscan_cmd" --VERSION 2> /dev/null)
    
    # shellcheck disable=SC2181
    if [[ "$?" == "0" ]]; then
        uvscan_status=$cmd_result
    else
        printf "%s\n" "$__vscl_invalid_code"
        return 1
    fi
        
    # parse DAT version
    local_dat_ver=$(printf "%s\n" "$uvscan_status" | grep -i "dat set version:" | cut -d' ' -f4)
    
    # parse engine version
    local_eng_ver=$(printf "%s\n" "$uvscan_status" | grep -i "av engine version:" | cut -d' ' -f4)
    
    # parse executable version
    local_exe_ver=$(printf "%s\n" "$uvscan_status" | grep -i "Command Line for Linux64 Version:" | cut -d' ' -f8)
    
    # default to printing entire DAT and engine string, i.e. "9999.0 (9999.9999)"
    out_text=$(printf "%s.0 (%s)\n" "$local_dat_ver" "$local_eng_ver")

    if [[ -n $1 ]]; then
        case $1 in
            # Extract everything up to first '.'
            "DATMAJ") out_text="$(echo "$local_dat_ver" | cut -d. -f-1)"
                ;; 
            # Always returns "0" with current engine/DATs
            "DATMIN") out_text="0"
                ;;
            # Extract everything up to first '.'
            "ENGMAJ") out_text="$(echo "$local_eng_ver" | cut -d. -f-1)"
                ;;
            # Extract everything after first '.'
            "ENGMIN") out_text="$(echo "$local_eng_ver" | cut -d' ' -f1 | cut -d. -f2-)"
                ;;
            # Extract everything after first '.'
            "EXEVER") out_text="$local_exe_ver"
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    fi
    
    # return string STDOUT
    printf "%s\n" "$out_text"

    return 0
}

#-----------------------------------------------------------------------------

function download_file {
    #------------------------------------------------------------
    # Function to download a specified file from EPO repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #------------------------------------------------------------

    declare file_name download_url fetcher fetcher_cmd fetcher_arg

    # get the available HTTP download tool, preference to "wget", but "curl" is ok
    if command -v wget > /dev/null 2>&1; then
        fetcher="wget"
    elif command -v curl > /dev/null 2>&1; then
        fetcher="curl"
    else
        # no HTTP download tool available, exit script
        exit_with_error "No valid URL fetcher available!"
    fi

    # type must be "bin" or "ascii"
    if [[ "$3" != "bin" ]] && [[ "$3" != "ascii" ]]; then
        exit_with_error "Download type must be 'bin' or 'ascii'!"
    fi

    file_name="$4/$2"
    download_url="$1/$2"

    # download with available download tool
    case $fetcher in
        "wget") fetcher_cmd="wget"
                fetcher_arg="--quiet --tries=10 --no-check-certificate --output-document=""$file_name"" $download_url"
            ;;
        "curl") fetcher_cmd="curl"
                fetcher_arg="-s -k ""$download_url"" -o ""$file_name"""
            ;;
        *) exit_with_error "No valid URL fetcher available!"
            ;;
    esac

    
    if capture_command "$fetcher_cmd" "$fetcher_arg"; then
        # file downloaded OK
        if [[ "$3" = "ascii" ]]; then
            # strip any CR/LF line terminators
            tr -d '\r' < "$file_name" > "$file_name.tmp"
            rm -f "$file_name"
            mv "$file_name.tmp" "$file_name"
        fi
    else
        exit_with_error "Unable to download '$download_url' to '$file_name'!"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------

function validate_file {
    #------------------------------------------------------------
    # Function to check the specified file against its expected
    # size, checksum and md5_sum checksum.
    #------------------------------------------------------------
    # Params: $1 - File name (including path)
    #         $2 - expected size
    #         $3 - md5_sum Checksum
    #------------------------------------------------------------

    local size md5_sum_csum md5_sum_checker
        
    # Optional: Program for calculating the md5_sum for a file
    md5_sum_checker="md5_sum"

    # Check the file size matches what we expect...
    size=$(stat "$1" --printf "%s")

    if [[ -n "$size" ]] && [[ "$size" = "$2" ]]; then
        log_info "File '$1' size is correct ($2)"
    else
        exit_with_error "Downloaded DAT size '$size' should be '$1'!"
    fi

    # make md5_sum check optional. return "success" if there's no support
    if [[ -z "$md5_sum_checker" ]] || [[ ! -x $(command -v $md5_sum_checker 2> /dev/null) ]]; then
        log_warning "md5_sum Checker not available, skipping md5_sum check..."
        return 0
    fi

    # Check the md5_sum checksum...
    md5_sum_csum=$($md5_sum_checker "$1" 2>/dev/null | cut -d' ' -f1)

    if [[ -n "$md5_sum_csum" ]] && [[ "$md5_sum_csum" = "$3" ]]; then
        log_info "File '$1' md5_sum checksum is correct ($3)"
    else
        exit_with_error "Downloaded DAT md5_sum hash '$md5_sum_csum' should be '$3'!"
    fi

    return 0
}

#-----------------------------------------------------------------------------

function copy_files_with_modes {
    #--------------------------------------------------------------------
    # Function to copy one file from source to destination
    #--------------------------------------------------------------------
    # Params: $1 - List of files to copy
    #              (format => <filepath>:<chmod>, relative path OK)
    #         $2 - Destination directory (including path, relative OK)
    #--------------------------------------------------------------------
    declare files_to_copy fname_modes file_name file_mode

    # echo "\$1 = '$1'"
    # echo "\$2 = '$2'"

    if [[ ! -d $2 ]]; then
        exit_with_error "'$2' is not a directory!"
    fi

    # strip filename to a list
    for fname_modes in $1; do
        # echo "\$fname_modes = '$fname_modes'"
        file_name=$(printf "%s\n" "$fname_modes" | awk -F':' ' { print $1 } ')
        files_to_copy="$files_to_copy $file_name"
        echo "\$files_to_copy = '$files_to_copy'"
    done

    if ! /usr/bin/cp "$files_to_copy" "$2"; then
        exit_with_error "Unable to copy '$files_to_copy' to '$2'!"
    fi

    # apply chmod permissions from list
    for fname_modes in $1; do
        file_name=$(printf "%s\n" "$fname_modes" | awk -F':' ' { print $1 } ')
        file_mode=$(printf "%s\n" "$fname_modes" | awk -F':' ' { print $NF } ')
        
        if ! chmod "$file_mode $2/${file_name##*/}"; then
            exit_with_error "Unable to set mode '$file_mode' on '$2/${file_name##*/}'!"
        fi
    done

    return 0
}

#-----------------------------------------------------------------------------

function update_from_zip {
    #---------------------------------------------------------------
    # Function to extract the listed files from the given zip file.
    #---------------------------------------------------------------
    # Params: $1 - Directory to unzip to
    #         $2 - Downloaded zip file
    #         $3 - List of files to unzip
    #              (format => <filename>:<chmod>)
    #---------------------------------------------------------------

    declare files_to_download fname file_name unzip_options permissions

    # strip filename to a list
    for fname in $3; do
        file_name=$(printf "%s\n" "$fname" | awk -F':' ' { print $1 } ')
        files_to_download="$files_to_download $file_name"
    done

    # Update the DAT files.
    log_info "Uncompressing '$2' to '$1'..."
    unzip_options="-o -d $1 $2 $files_to_download"

    # shellcheck disable=SC2086
    if ! unzip $unzip_options > /dev/null 2>&1; then
        exit_with_error "Unable to unzip '$2' to '$1'!"
    fi

    # apply chmod permissions from list
    for fname in $3; do
        file_name=$(printf "%s\n" "$fname" | awk -F':' ' { print $1 } ')
        permissions=$(printf "%s\n" "$fname" | awk -F':' ' { print $NF } ')
        chmod "$permissions" "$1/$file_name"
    done

    return 0
}

function init_library {
    #---------------------------------------------------------------
    # Initialize the library functions
    #---------------------------------------------------------------
    # Switches:     -f: force library to load even if already loaded
    #---------------------------------------------------------------

    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    declare option_var

    while getopts :fu option_var; do
        echo "\$option_var = '$option_var'"
        case "$option_var" in
            # force library to load even if already loaded
            "f") #echo "force"
                 unset __vscl_lib_loaded
                ;;
            #"u") #echo "unload"
            #     unset -f  $( set | grep -i '^__vscl.*\ ()' | awk '{print $1}' )
            #     unset $( set | grep -i '^__vscl.*=.*' | awk -F"=" '{print $1}' )
            #     return 0
            #    ;;
            *)   echo "Unknown option '$option_var' specified!"
                 exit 1
                ;;
        esac
    done

    #-----------------------------------------
    # VSCL Library initialization code
    #-----------------------------------------
    __vscl_script_abbr="VSCLLIB"

    if [[ -z "$__vscl_temp_dir" ]]; then
        # no current temp directory specified in environment
        # __vscl_temp_dir must be a directory and writable
        __vscl_temp_dir=$( mktemp -d -p "$__vscl_script_path" 2> /dev/null )
    fi

    if [[ -d "$__vscl_temp_dir" ]]; then
        log_info "Temp dir = '$__vscl_temp_dir'"
    else
        exit_with_error "Unable to use temporary directory '$__vscl_temp_dir'"
    fi

    if [[ -z "$__vscl_temp_file" ]]; then
        # no current temp file specified in environment
        # __vscl_temp_file must be a file and writable
        __vscl_temp_file=$( mktemp -p "$__vscl_temp_dir" 2> /dev/null )
    fi

    if [[ -f "$__vscl_temp_file" ]]; then
        log_info "Temp file = '$__vscl_temp_file'"
    else
        exit_with_error "Unable to use temporary file '$__vscl_temp_file'"
    fi

    __vscl_save_ifs=$IFS
    return 0
}

#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
# File is sourced, execute initialization and return to sourcing code
init_library "$@"
return $?
