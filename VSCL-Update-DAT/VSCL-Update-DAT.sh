#!/bin/bash

#=============================================================================
# NAME:         update-vscl.sh
# Purpose:      Update the DAT files for the McAfee VirusScan Command Line
#                       Scanner 6.1.0 on SaaS Linux PPM App servers
# Creator:      Nick Taylor, Sr. Engineer, CA SaaS Ops
# Original:     Copyright (c) 2009 McAfee, Inc. All Rights Reserved.
# Date:         23-OCT-2017
# Version:      1.1
# PreReqs:      Linux
#               CA PPM Application Server
#               VSCL antivirus scanner installed
#               Latest VSCL DAT .ZIP file
#               unzip, tar, gunzip, gclib > 2.7 utilities in OS,
#               awk, echo, cut, ls, printf, wget
#=============================================================================
# Params:       none
#=============================================================================

#=============================================================================
# VARIABLES
#=============================================================================

# Defaults: Do not modify
#-----------------------------------------
unset MD5CHECKER LEAVE_FILES DEBUG_IT FETCHER
unset PERFORM_UPDATE LOCAL_VERSION_FILE DAT_ZIP

# Globals
# (these variables are normally best left unmodified)
#-----------------------------------------
# name of this script
SCRIPT_NAME=`basename "$0"`

# name of the Commercial site where script is running ("US5NP","AU1","DEMUN","SC5")
SITE_NAME="US5NP"

# McAfee repo server
EPO_SERVER="MCAFEE01"

# name of the repo file with current DAT version
VERSION_FILE="avvdat.ini"

# name of scanner executable
UVSCAN_EXE="uvscan"
UVSCAN_SWITCHES=""

# path to MACONFIG program
MACONFIG_PATH="/opt/McAfee/agent/bin/maconfig"

# path to CMDAGENT utility
CMDAGENT_PATH="/opt/McAfee/agent/bin/cmdagent"

# Change these variables to match your environment
# UVSCAN_DIR must be a directory and writable where uvscan is installed
UVSCAN_DIR="/usr/local/uvscan"

# TMP_DIR must be a directory and writable
TMP_DIR="/root/VSCL-TEMP"

# Name of the file in the repository to extract current DAT version from
LOCAL_VERSION_FILE="$TMP_DIR/$VERSION_FILE"

# section of avvdat.ini from repository to examine for DAT version
VER_SECTION="AVV-ZIP"

# Optional: Program for calculating the MD5 for a file
MD5CHECKER="MD5sum"

# Program to use to download files from web repository
# (default is wget but curl is OK)
FETCHER="wget"

# Preferences
#-----------------------------------------
# set to non-empty to leave downloaded files after the update is done
#LEAVE_FILES="true"
# show debug messages (set to non-empty to enable)
DEBUG_IT=yes

# download site
DOWNLOAD_SITE="https://${SITE_NAME}${EPO_SERVER}:443/Software/Current/VSCANDAT1000/DAT/0000"

# space-delimited list of files to unzip
# format => <filename>:<permissions>
FILE_LIST="avvscan.dat:444 avvnames.dat:444 avvclean.dat:444"

#=============================================================================
# FUNCTIONS
#=============================================================================

Do-Cleanup() {
    #------------------------------------------------------------
    # if 'LEAVE_FILES' global is NOT set, erase downloaded files
    #------------------------------------------------------------

    if [ -z "$LEAVE_FILES" ]
    then
        rm -rf "$TMP_DIR"
    fi
}

Exit-WithError() {
    #----------------------------------------------------------
    # if $1 param is set, print error msg
    # in any case, exit with error
    #----------------------------------------------------------

    if [ -n "$1" ]
    then
        printf "$SCRIPT_NAME: $1\n"
    fi

    Do-Cleanup
    exit 1
}

Debug-Print() {
    #----------------------------------------------------------
    # if 'DEBUG_IT' global is set, print params
    #----------------------------------------------------------

    if [ -n "$DEBUG_IT" ]
    then
        printf "$SCRIPT_NAME: [debug] $@\n"
    fi
}

Find-INISection() {
    #----------------------------------------------------------
    # Function to parse avvdat.ini and return, via stdout, the
    # contents of a specified section. Requires the avvdat.ini
    # file to be available on stdin.
    #----------------------------------------------------------
    # Params: $1 - Section name
    #----------------------------------------------------------
    # Output: space-delimited INI entries
    #----------------------------------------------------------

    unset SECTION_FOUND

    SECTION_NAME="[$1]"

    while read LINE
    do
        if [ "$LINE" = "$SECTION_NAME" ]
        then
            SECTION_FOUND="true"
        elif [ -n "$SECTION_FOUND" ]
        then
            if [ "`echo $LINE | cut -c1`" != "[" ]
            then
                if [ -n "$LINE" ]
                then
                    printf "$LINE\n"
                fi
            else
                unset SECTION_FOUND
            fi
        fi
    done
}

Get-CurrentDATVersion() {
    #------------------------------------------------------------
    # Function to return the DAT version currently installed for
    # use with the command line scanner
    #------------------------------------------------------------

    UVSCAN_DAT=`("$UVSCAN_DIR/$UVSCAN_EXE" $2 --version )`

    if [ $? -ne 0 ]
    then
        return 1
    fi

    LOCAL_DAT_VERSION=`printf "$UVSCAN_DAT\n" | grep -i "dat set version:" | cut -d' ' -f4`
    printf "${LOCAL_DAT_VERSION}.0\n"

    return 0
}

Download-File() {
    #------------------------------------------------------------
    # Function to download a specified file from repository
    #------------------------------------------------------------
    # Params: $1 - Download site
    #         $2 - Name of file to download.
    #         $3 - Download type (either bin or ascii)
    #         $4 - Local download directory
    #------------------------------------------------------------

    # type must be "bin" or "ascii"
    if [ "$3" != "bin" -a "$3" != "ascii" ]
    then
        Exit-WithError "Download type must be 'bin' or 'ascii'!"
    fi

    # download with wget
    case $FETCHER in
        "wget")
            wget -q --no-check-certificate "$1/$2" -O $4/$2
            ;;
        "curl")
            curl -s -k "$1/$2" -o $4/$2
            ;;
        *)
            Exit-WithError "No valid URL fetcher available!"
            ;;
    esac

    if [ $? -eq 0 ]
    then
        # file downloaded OK
        if [ "$3" = "ascii" ]
        then
            # strip and CR/LF line terminators
            tr -d '\r' < "$4/$2" > "$4/$2.tmp"
            rm -f "$4/$2"
            mv "$4/$2.tmp" "$4/$2"
        fi

        return 0
    fi

    Exit-WithError "Cannot download '$2' from '$1'!"
}

Validate-File() {
    #------------------------------------------------------------
    # Function to check the specified file against its expected
    # size, checksum and MD5 checksum.
    #------------------------------------------------------------
    # Params: $1 - File name (including path)
    #         $2 - expected size
    #         $3 - MD5 Checksum
    #------------------------------------------------------------

    # Check the file size matches what we expect...
    SIZE=`ls -l "$1" | awk ' { print $5 } '`
    [ -n "$SIZE" -a "$SIZE" = "$2" ] || Exit-WithError "Downloaded DAT size '$SIZE' should be '$1'!"

    # make MD5 check optional. return "success" if there's no support
    [ -z "$MD5CHECKER" -o "(" ! -x "`which $MD5CHECKER 2> /dev/null`" ")" ] && return 0

    # Check the MD5 checksum...
    MD5_csum=`$MD5CHECKER "$1" 2>/dev/null | cut -d' ' -f1`
    [ -n "$MD5_csum" -a "$MD5_csum" = "$3" ] # return code
}

Update-FromZip() {
    #---------------------------------------------------------------
    # Function to extract the listed files from the given zip file.
    #---------------------------------------------------------------
    # Params: $1 - Directory to unzip to
    #         $2 - Downloaded zip file
    #         $3 - Dist of files to unzip
    #              (format => <filename>:<chmod>)
    #---------------------------------------------------------------

    unset FILE_LIST

    # strip filename to a list
    for FNAME in $3
    do
        FILE_NAME=`printf "$FNAME\n" | awk -F':' ' { print $1 } '`
        FILE_LIST="$FILE_LIST $FILE_NAME"
    done

    # Backup any files about to be updated...
    [ ! -d "backup" ] && mkdir backup 2>/dev/null
    [ -d "backup" ] && cp $FILE_LIST "backup" 2>/dev/null

    # Update the DAT files.
    Debug-Print "Uncompressing '$2' to '$1'..."
    unzip -o -d $1 $2 $FILE_LIST >/dev/null || Exit-WithError "Error unzipping '$2' to '$1'!"

    # apply chmod permissions from list
    for FNAME in $3
    do
        FILE_NAME=`printf "$FNAME\n" | awk -F':' ' { print $1 } '`
        PERMISSIONS=`printf "$FNAME\n" | awk -F':' ' { print $NF } '`
        chmod "$PERMISSIONS" "$1/$FILE_NAME"
    done

    return 0
}

Check-For() {
    #------------------------------------------------------------
    # Function to check for existence of a file
    #------------------------------------------------------------
    # Params:  $1 = full path to file
    #          $2 = friendly-name of file
    #          $3 = (optional) --no-terminate to return always
    #------------------------------------------------------------
    Debug-Print "Checking for '$2' at '$1'..."

    if [ ! -x "$1" ]
    then
        if [ "$3" = "--no-terminate" ]
        then
            return 1
        else
            Exit-WithError "Could not find '$2' at '$1'!"
        fi
    fi
    
    return 0
}

Set-CustomProp1() {
    #------------------------------------------------------------
    # Set the value of McAfee custom Property #1
    #------------------------------------------------------------
    # Params:  $1 = value to set property
    #------------------------------------------------------------
    Debug-Print "Setting EPO Custom Property #1 to '$1'..."

    $MACONFIG_PATH -custom -prop1 "$1"

    if [ $? -ne 0 ]
    then
        Exit-WithError "Error setting EPO Custom Property #1 to '$1'!"
    fi
    
    return 0
}

Refresh-ToEPO() {
    #------------------------------------------------------------
    # Function to refresh the agent with EPO
    #------------------------------------------------------------

    # flags to use with CMDAGENT utility
    unset CMDAGENT_FLAGS
    CMDAGENT_FLAGS="-c -f -p -e"

    Debug-Print "Refreshing agent data with EPO..."
    
    # loop through provided flags and call one command per
    # (CMDAGENT can't handle more than one)
    for FLAG_NAME in $CMDAGENT_FLAGS
    do
        $CMDAGENT_PATH $FLAG_NAME
        
        if [ $? -ne 0 ]
        then
            Exit-WithError "Error running EPO refresh command '$CMDAGENT_PATH $FLAG_NAME'!"
        fi
    done
    
    return 0
}

#=============================================================================
#  MAIN PROGRAM
#=============================================================================

# sanity checks
# check for wget
if [ `which wget 2>null` ]
then
    FETCHER="wget"
elif [ `which curl 2>null` ]
then
    FETCHER="curl"
else
    Exit-WithError "No valid URL fetcher available!"
fi

# check for MACONFIG
Check-For $MACONFIG_PATH "MACONFIG utility"

# check for CMDAGENT
Check-For $CMDAGENT_PATH "CMDAGENT utility"

# check for uvscan
Check-For $UVSCAN_DIR/$UVSCAN_EXE "uvscan executable" --no-terminate

if [ $? -ne 0 ]
then
    # uvscan not found
    # set custom property to error value, then exit with error
    Debug-Print "Could not find 'uvscan executable' at '$UVSCAN_DIR/$UVSCAN_EXE'!"
    Debug-Print "Setting McAfee Custom Property #1 to 'VSCL:NOT INSTALLED'..."
    Set-CustomProp1 "VSCL:NOT INSTALLED"
    Refresh-ToEPO   
    exit 0
fi

# make temp dir if it doesn't exist
Debug-Print "Checking for temporary directory '$TMP_DIR'..."

if [ ! -d "$TMP_DIR" ]
then
    Debug-Print "Creating temporary directory '$TMP_DIR'..."
    mkdir -p "$TMP_DIR" 2>/dev/null
fi

if [ ! -d "$TMP_DIR" ]
then
    Exit-WithError "Error creating temporary directory '$TMP_DIR'!"
fi

# download current DAT version file from repository, exit if not available
Debug-Print "Downloading file '$VERSION_FILE' from '$DOWNLOAD_SITE'..."
Download-File "$DOWNLOAD_SITE" "$VERSION_FILE" "ascii" "$TMP_DIR"

if [ $? -ne 0 ]
then
    Exit-WithError "Error downloading '$VERSION_FILE' from '$DOWNLOAD_SITE'!"
fi

# Did we get the version file?
if [ ! -r "$LOCAL_VERSION_FILE" ]
then
    Exit-WithError "Error downloading '$VERSION_FILE' from '$DOWNLOAD_SITE'!"
fi

# Get the version of the installed DATs...
Debug-Print "Determining the currently running DAT version..."
CURRENT_DAT=`Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE" "$UVSCAN_SWITCHES"`

if [ -z "$CURRENT_DAT" -o $? -ne 0 ]
then
    Debug-Print "Unable to determine currently installed DAT version!"
    CURRENT_DAT="0000.0"
fi

CURRENT_MAJOR=`echo "$CURRENT_DAT" | cut -d. -f-1`
CURRENT_MINOR=`echo "$CURRENT_DAT" | cut -d. -f2-`

# extract DAT info from avvdat.ini
Debug-Print "Determining the available DAT version..."
unset INI_SECTION
Debug-Print "Finding section for current DAT version in '$LOCAL_VERSION_FILE'..."
INI_SECTION=`Find-INISection $VER_SECTION < $LOCAL_VERSION_FILE`

if [ -z "$INI_SECTION" ]
then
    Exit-WithError "Unable to find section '$INI_SECTION' in '$LOCAL_VERSION_FILE'!"
fi

unset MAJOR_VER FILE_NAME FILE_PATH FILE_SIZE MD5
# Some INI sections have the MinorVersion field missing.
# To work around this, we will initialise it to 0.
MINOR_VER=0

unset INI_FIELD

# Parse the section and keep what we are interested in.
for INI_FIELD in $INI_SECTION
do
    FIELD_NAME=`echo "$INI_FIELD" | awk -F'=' ' { print $1 } '`
    FIELD_VALUE=`echo "$INI_FIELD" | awk -F'=' ' { print $2 } '`

    case $FIELD_NAME in
        "DATVersion") MAJOR_VER="$FIELD_VALUE" ;; # available: major
        "MinorVersion") MINOR_VER="$FIELD_VALUE" ;; # available: minor
        "FileName") FILE_NAME="$FIELD_VALUE" ;; # file to download
        "FilePath") FILE_PATH="$FIELD_VALUE" ;; # path on FTP server
        "FileSize") FILE_SIZE="$FIELD_VALUE" ;; # file size
        "MD5") MD5="$FIELD_VALUE" ;; # MD5 checksum
    esac
done

# sanity check
# All extracted fields have values?
if [ -z "$MAJOR_VER" -o -z "$MINOR_VER" -o -z "$FILE_NAME" -o -z "$FILE_PATH" -o -z "$FILE_SIZE" -o -z "$MD5" ]
then
    Exit-WithError "Section '[$INI_SECTION]' in '$LOCAL_VERSION_FILE' has incomplete data!"
fi

# Installed version is less than current DAT version?
if (( $CURRENT_MAJOR < $MAJOR_VER )) || ( (( $CURRENT_MAJOR == $MAJOR_VER )) && (( $CURRENT_MINOR < $MINOR_VER )) )
then
    PERFORM_UPDATE="yes"
fi

# OK to perform update?
if [ -n "$PERFORM_UPDATE" ]
then
    Debug-Print "Performing an update ($CURRENT_DAT -> $MAJOR_VER.$MINOR_VER)..."

    # Download the dat files...
    Debug-Print "Downloading the current DAT from '$DOWNLOAD_SITE'..."
    Download-File "$DOWNLOAD_SITE" "$FILE_NAME" "bin" "$TMP_DIR"

    if [ $? -ne 0 ]
    then
        Exit-WithError "Error downloading '$FILE_NAME' from '$DOWNLOAD_SITE'!"
    fi

    DAT_ZIP="$TMP_DIR/$FILE_NAME"

    # Did we get the dat update file?
    if [ ! -r "$DAT_ZIP" ]
    then
        Exit-WithError "Unable to access DAT file '$DAT_ZIP'!"
    fi

    Validate-File "$DAT_ZIP" "$FILE_SIZE" "$MD5"

    if [ $? -ne 0 ]
    then
        Exit-WithError "DAT update failed - Validation failed for '$TMP_DIR/$FILE_NAME'!"
    fi

    Update-FromZip "$UVSCAN_DIR" "$DAT_ZIP" "$FILE_LIST"

    if [ $? -ne 0 ]
    then
        Exit-WithError "Error unzipping DATs from file '$TMP_DIR/$DAT_ZIP'!"
    fi

    # Check the new version matches the downloaded one.
    Debug-Print "Starting up uvscan with new DAT files..."
    NEW_VERSION=`Get-CurrentDATVersion "$UVSCAN_DIR/$UVSCAN_EXE" "$UVSCAN_SWITCHES"`

    if [ -z "$NEW_VERSION" ]
    then
        # Could not determine current value for DAT version from uvscan
        # set custom property to error value, then exit with error
        Debug-Print "Unable to determine currently installed DAT version!"
        NEW_VERSION="VSCL:INVALID DAT"
    else

        Debug-Print "Checking that the installed DAT matches the available DAT version..."
        NEW_MAJOR=`echo "$NEW_VERSION" | cut -d. -f-1`
        NEW_MINOR=`echo "$NEW_VERSION" | cut -d. -f2-`

        if (( $NEW_MAJOR == $MAJOR_VER )) && (( $NEW_MINOR == $MINOR_VER))
        then
            Debug-Print "DAT update succeeded ($CURRENT_DAT -> $NEW_VERSION)!"
        else
            Exit-WithError "DAT update failed - installed version different than expected!"
        fi
        
        NEW_VERSION="VSCL=$NEW_VERSION"
    fi

    # Set McAfee Custom Property #1 to '$NEW_VERSION'...
    Set-CustomProp1 "$NEW_VERSION"
	
	# Refresh agent data with EPO
    Refresh-ToEPO   
    exit 0
else
    Debug-Print "Installed DAT is already up to date ($CURRENT_DAT)!  Exiting..."
fi

Do-Cleanup
exit 0
