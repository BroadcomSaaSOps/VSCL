#!/bin/bash

#=============================================================================
# Name:     VSCL-Update-DAT.sh
#-----------------------------------------------------------------------------
# Purpose:  Update the DAT files for the McAfee VirusScan Command Line
#                       Scanner 6.1.3 on SaaS Linux PPM App servers from EPO
#-----------------------------------------------------------------------------
# Creator:  Nick Taylor, Pr. Engineer, Broadcom SaaS Ops
#-----------------------------------------------------------------------------
# Date:     03-FEB-2020
#-----------------------------------------------------------------------------
# Version:  1.2
#-----------------------------------------------------------------------------
# PreReqs:  Linux
#           CA PPM Application Server
#           VSCL antivirus scanner installed
#           Latest VSCL DAT .ZIP file
#           unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#           awk, echo, cut, ls, printf, wget
#-----------------------------------------------------------------------------
# Params:   none
#-----------------------------------------------------------------------------
# Switches: -d:  download current DATs and exit
#           -l:  leave any files extracted intact at exit
#-----------------------------------------------------------------------------
# Imports:  ./VSCL-lib.sh:          VSCL library functions
#           ./VSCL-Update-Prop1.sh: self-contained Custom Prop #1 updater
#=============================================================================

#=============================================================================
# PREPROCESS: Bypass inclusion of this file if it is already loaded
#=============================================================================
if [[ -z "$__VSCL_UDD_LOADED" ]]; then
    # not already loaded, set flag that it is now
    #echo "not loaded, loading..."
    __VSCL_UDD_LOADED=1
else
    # already loaded, exit gracefully
    #echo "loaded already"
    return 0
fi

#=============================================================================
#  IMPORTS: Import any required libraries/files
#=============================================================================
# shellcheck disable=SC1091
unset INCLUDE_PATH
INCLUDE_PATH="${BASH_SOURCE%/*}"
. "$INCLUDE_PATH/VSCL-lib.sh"
# shellcheck disable=SC1091
. "$INCLUDE_PATH/VSCL-Update-Prop1.sh"


#=============================================================================
# GLOBALS: Global variables
#=============================================================================
# Abbreviation of this script name for logging, NOT set if sourced
# shellcheck disable=2034
if [[ -z "$__VSCL_SCRIPT_ABBR" ]]; then
    __VSCL_SCRIPT_ABBR="VCSLUDAT"
fi


#=============================================================================
# FUNCTION: primary function of script
#=============================================================================
function Update_DAT () {
    #-----------------------------------------
    # Process command line options
    #-----------------------------------------
    # shellcheck disable=2034
    #OPTIND=1

    while getopts :dl OPTION_VAR; do
        case "$OPTION_VAR" in
            "d") DOWNLOAD_ONLY=1    # only download most current DAT from EPO and exit
                ;;
            "l") __VSCL_LEAVE_FILES=1      # leave any temp files on exit
                ;;
            *) Exit_WithError "Unknown option specified!"
                ;;
        esac
    done

    shift "$((OPTIND-1))"

    #-----------------------------------------
    # Local variables
    #-----------------------------------------
    # Name of the file in the repository to extract current DAT version from
    LOCAL_VER_FILE="$__VSCL_TEMP_DIR/$__VSCL_EPO_VER_FILE"

    # download site
    # shellcheck disable=SC2153
    DOWNLOAD_SITE="https://${__VSCL_SITE_NAME}${__VSCL_EPO_SERVER}:443/Software/Current/VSCANDAT1000/DAT/0000"


    #-----------------------------------------
    #  Main code of update function
    #-----------------------------------------
    Log_Info "==========================="
    Log_Info "Beginning VSCL DAT update"
    Log_Info "==========================="

    if [[ -z "$DOWNLOAD_ONLY" ]]; then
        # check for MACONFIG
        Check_For "$__VSCL_MACONFIG_PATH" "MACONFIG utility"

        # check for CMDAGENT
        Check_For "$__VSCL_CMDAGENT_PATH" "CMDAGENT utility"

        # check for uvscan
        if ! Check_For "$__VSCL_UVSCAN_DIR/$__VSCL_UVSCAN_EXE" "uvscan executable" --no-terminate; then
            # uvscan not found
            # set custom property to error value, then exit
            Log_Info "Could not find 'uvscan executable' at '$__VSCL_UVSCAN_DIR/$__VSCL_UVSCAN_EXE'!"
            Log_Info "Setting McAfee Custom Property #1 to '$__VSCL_NOTINST_CODE'..."
            Set_CustomProp 1 "$__VSCL_NOTINST_CODE"
            Refresh_ToEPO
            Exit_WithError "Cannot update DATs, VSCL not installed!"
        fi
    fi

    # make temp dir if it doesn't exist
    Log_Info "Checking for temporary directory '$__VSCL_TEMP_DIR'..."

    if [[ ! -d "$__VSCL_TEMP_DIR" ]]; then
        Log_Info "Creating temporary directory '$__VSCL_TEMP_DIR'..."

        if ! mkdir -p "$__VSCL_TEMP_DIR" 2> /dev/null; then
            Exit_WithError "Error creating temporary directory '$__VSCL_TEMP_DIR'!"
        fi
    fi

    if [[ ! -d "$__VSCL_TEMP_DIR" ]]; then
        Exit_WithError "Error creating temporary directory '$__VSCL_TEMP_DIR'!"
    fi

    # download current DAT version file from repository, exit if not available
    Log_Info "Downloading DAT versioning file '$__VSCL_EPO_VER_FILE' from '$DOWNLOAD_SITE'..."

    #DOWNLOAD_OUT="$?"

    if ! Download_File "$DOWNLOAD_SITE" "$__VSCL_EPO_VER_FILE" "ascii" "$__VSCL_TEMP_DIR"; then
        Exit_WithError "Error downloading '$__VSCL_EPO_VER_FILE' from '$DOWNLOAD_SITE'!"
    fi

    # Did we get the version file?
    if [[ ! -r "$LOCAL_VER_FILE" ]]; then
        Exit_WithError "***Error downloading '$__VSCL_EPO_VER_FILE' from '$DOWNLOAD_SITE'!"
    fi

    #cat $LOCAL_VER_FILE 
    #ls -lAh $LOCAL_VER_FILE

    if [[ -z "$DOWNLOAD_ONLY" ]]; then
        #ls -lAh $LOCAL_VER_FILE
        # Get the version of the installed DATs...
        Log_Info "Determining the currently installed DAT version..."
        #ls -lAh $LOCAL_VER_FILE

        unset CURR_DAT
        #ls -lAh $LOCAL_VER_FILE
        #echo "a"
        CURR_DAT=$(Get_CurrDATVer)
        #echo "b"
        #ls -lAh $LOCAL_VER_FILE

        if [[ -z "$CURR_DAT" ]] ; then
            Log_Info "Unable to determine currently installed DAT version!"
            CURR_DAT="0000.0"
        else
            unset CURR_MAJOR CURR_MINOR
            CURR_MAJOR=$(Get_CurrDATVer "DATMAJ")
            CURR_MINOR=$(Get_CurrDATVer "DATMIN")
        fi
    fi
    #ls -lAh $LOCAL_VER_FILE
    # extract DAT info from avvdat.ini
    Log_Info "Determining the available DAT version..."
    unset INI_SECTION
    Log_Info "Finding section for current DAT version in '$LOCAL_VER_FILE'..."
    #echo "pwd = '`pwd`'"
    #echo "\$LOCAL_VER_FILE = '$LOCAL_VER_FILE'"
    #echo "\$__VSCL_EPO_VER_SECTION = '$__VSCL_EPO_VER_SECTION'"
    #cat $LOCAL_VER_FILE 
    #ls -lAh $LOCAL_VER_FILE
    #echo "\$__VSCL_TEMP_DIR = '$__VSCL_TEMP_DIR'"
    #ls -lAh $__VSCL_TEMP_DIR
    INI_SECTION=$(Find_INISection "$__VSCL_EPO_VER_SECTION" < "$LOCAL_VER_FILE")

    if [[ -z "$INI_SECTION" ]]; then
        Exit_WithError "Unable to find section '$__VSCL_EPO_VER_SECTION' in '$LOCAL_VER_FILE'!"
    fi

    unset INI_FIELD AVAIL_MAJOR AVAIL_MINOR FILE_NAME FILE_PATH FILE_SIZE MD5
    # Some INI sections have the MinorVersion field missing.
    # To work around this, we will initialise it to 0.
    AVAIL_MINOR=0

    # Parse the section and keep what we are interested in.
    for INI_FIELD in $INI_SECTION; do
        FIELD_NAME=$(echo "$INI_FIELD" | awk -F'=' ' { print $1 } ')
        FIELD_VALUE=$(echo "$INI_FIELD" | awk -F'=' ' { print $2 } ')

        case $FIELD_NAME in
            "DATVersion") AVAIL_MAJOR="$FIELD_VALUE"  # available: major
                ;; 
            "MinorVersion") AVAIL_MINOR="$FIELD_VALUE" # available: minor
                ;;
            "FileName") FILE_NAME="$FIELD_VALUE" # file to download
                ;;
            "FilePath") FILE_PATH="$FIELD_VALUE" # path on FTP server
                ;;
            "FileSize") FILE_SIZE="$FIELD_VALUE" # file size
                ;;
            "MD5") MD5="$FIELD_VALUE" # MD5 checksum
                ;;
            *) true  # ignore any other fields
                ;;
        esac
    done

    # sanity check
    # All extracted fields have values?
    if [[ -z "$AVAIL_MAJOR" ]] || [[ -z "$AVAIL_MINOR" ]] || [[ -z "$FILE_NAME" ]] || [[ -z "$FILE_PATH" ]] || [[ -z "$FILE_SIZE" ]] || [[ -z "$MD5" ]]; then
        Exit_WithError "Section '[$INI_SECTION]' in '$LOCAL_VER_FILE' has incomplete data!"
    fi

    Log_Info "Current DAT Version: '$CURR_MAJOR.$CURR_MINOR'"
    Log_Info "New DAT Version Available: '$AVAIL_MAJOR.$AVAIL_MINOR'"

    unset PERFORM_UPDATE

    if [[ -z "$DOWNLOAD_ONLY" ]]; then
        if [[ "$CURR_MAJOR" = "$__VSCL_INVALID_CODE" ]]; then
            PERFORM_UPDATE="yes";
        # Installed version is less than current DAT version?
        elif (( CURR_MAJOR < AVAIL_MAJOR )) || ( (( CURR_MAJOR == AVAIL_MAJOR )) && (( CURR_MINOR < AVAIL_MINOR )) ); then
            PERFORM_UPDATE="yes"
        fi
    fi

    # OK to perform update?
    if [[ -n "$PERFORM_UPDATE" ]] || [[ -n "$DOWNLOAD_ONLY" ]]; then
        if [[ -n "$PERFORM_UPDATE" ]]; then
            Log_Info "Performing an update ($CURR_DAT -> $AVAIL_MAJOR.$AVAIL_MINOR)..."
        fi

        # Download the dat files...
        Log_Info "Downloading the current DAT '$FILE_NAME' from '$DOWNLOAD_SITE'..."

        Download_File "$DOWNLOAD_SITE" "$FILE_NAME" "bin" "$__VSCL_TEMP_DIR"
        DOWNLOAD_OUT="$?"

        if [[ "$DOWNLOAD_OUT" != "0" ]]; then
            Exit_WithError "Error downloading '$FILE_NAME' from '$DOWNLOAD_SITE'!"
        fi

        DAT_ZIP="$__VSCL_TEMP_DIR/$FILE_NAME"

        # Did we get the dat update file?
        if [[ ! -r "$DAT_ZIP" ]]; then
            Exit_WithError "Unable to download DAT file '$DAT_ZIP'!"
        fi

        Validate_File "$DAT_ZIP" "$FILE_SIZE" "$MD5"
        VALIDATE_OUT="$?"

        if [[ "$VALIDATE_OUT" != "0" ]]; then
            Exit_WithError "DAT download failed - Validation failed for '$__VSCL_TEMP_DIR/$FILE_NAME'!"
        fi

        # Exit if we only wanted to download
        if [[ -n "$DOWNLOAD_ONLY" ]]; then
            #Do_Cleanup
            Log_Info "DAT downloaded to '$__VSCL_DAT_ZIP'.  Exiting.."
            Exit_Script 0
        fi

        Update_FromZip "$__VSCL_UVSCAN_DIR" "$DAT_ZIP" "$__VSCL_EPO_FILE_LIST"
        UPDATE_OUT="$?"

        if [[ "$UPDATE_OUT" != "0" ]] ; then
            Exit_WithError "Error unzipping DATs from file '$__VSCL_TEMP_DIR/$__VSCL_DAT_ZIP'!"
        fi

        # Check the new version matches the downloaded one.
        Log_Info "Starting up uvscan with new DAT files..."
        NEW_VER=$(Get_CurrDATVer)

        if [[ -z "$NEW_VER" ]]; then
            # Could not determine current value for DAT version from uvscan
            # set custom property to error value, then exit with error
            Log_Info "Unable to determine currently installed DAT version!"
            NEW_VER="$__VSCL_INVALID_CODE"
        else
            Log_Info "Checking that the installed DAT matches the available DAT version..."
            NEW_MAJOR=$(Get_CurrDATVer "DATMAJ")
            NEW_MINOR=$(Get_CurrDATVer "DATMIN")

            #Log_Info "NEW_MAJOR = '$NEW_MAJOR'"
            #Log_Info "NEW_MINOR = '$NEW_MINOR'"
            #Log_Info "AVAIL_MAJOR = '$AVAIL_MAJOR'"
            #Log_Info "AVAIL_MINOR = '$AVAIL_MINOR'"

            if (( NEW_MAJOR != AVAIL_MAJOR )) || (( NEW_MINOR != AVAIL_MINOR )); then
                Exit_WithError "DAT update failed - installed version different than expected!"
            else
                Log_Info "DAT update succeeded ($CURR_DAT -> $NEW_VER)!"
            fi

            NEW_VER="VSCL:$NEW_VER"
        fi

        # Set McAfee Custom Property #1 to '$NEW_VER'...
        Update_Prop1
        return $?
    else
        if [[ -z "$PERFORM_UPDATE" ]]; then
            Log_Info "Installed DAT is already up to date ($CURR_DAT)!  Exiting..."
        fi
    fi

    return 0
}


#=============================================================================
# MAIN: Code execution begins here
#=============================================================================
if $(return 0 2>/dev/null); then
    # File is sourced, return to sourcing code
    Log_Info "VSCL Update DAT functions loaded successfully!"
    return 0
else
    # File is NOT sourced, execute it like it any regular shell file
    Update_DAT "$@"
    
    # Clean up global variables and exit cleanly
    Exit_Script $?
fi
