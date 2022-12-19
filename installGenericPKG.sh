#!/bin/bash

#set -x
#verboseMode=1

scriptVersion="v2.2.1"

##Written by Trevor Sysock (aka @bigmacadmin) at Second Son Consulting Inc.
#
#	THIS SOFTWARE IS BEING PROVIDED WITH THE ASSOCIATED LICENSE ON GITHUB: 
#	https://github.com/SecondSonConsulting/macOS-Scripts
#
#	This is provided with no warranty or assurances of any kind, please review in detail prior to use
#
########################################################################
#																	   #
#  Covered Software is provided under this License on an "as is"       #
#  basis, without warranty of any kind, either expressed, implied, or  #
#  statutory, including, without limitation, warranties that the       #
#  Covered Software is free of defects, merchantable, fit for a        #
#  particular purpose or non-infringing. The entire risk as to the     #
#  quality and performance of the Covered Software is with You.        #
#  Should any Covered Software prove defective in any respect, You     #
#  (not any Contributor) assume the cost of any necessary servicing,   #
#  repair, or correction. This disclaimer of warranty constitutes an   #
#  essential part of this License. No use of any Covered Software is   #
#  authorized under this License except under this disclaimer.         #
#																	   #
########################################################################
#
#Usage:
# Can be run as a Mosyle Custom Command or locally.
# Any step in the script that fails will produce an easily read error report to standard output.
# Uncomment set -x and/or verboseMode=1 at the top of the script for advanced debugging

# Arguments can be defined here in the script, or passed at the command line. 
# If passed at the command line, arguments MUST BE IN THE FOLLOWING ORDER:
# ./installGenericPKG.sh [pathtopackage] [md5 | TeamID]

# TeamID and MD5 are not required fields, but are strongly recommended to ensure you install 
# what you think you are installing.

# PKGs can be validated prior to install by either the TeamID or an MD5 hash.
# If both TeamID and MD5 are defined in the script, both will be checked.
# When running from the command line, md5 and TeamID can be passed as either argument 2 or 3 or both
# 
# Example: Download a PKG at https://test.example.host.tld/Remote.pkg and verify by TeamID
# ./installGenericPKG.sh https://test.example.host.tld/Remote.pkg 7Q6XP5698G
#
# Example: Run a PKG from the local disk and verify by TeamID and MD5
# ./installGenericPKG.sh /path/to/installer.pkg 7Q6XP5698G 9741c346eeasdf31163e13b9db1241b3
#


######################################
#
# User Configuration
#
######################################

#This is low consequence, and only used for the temp directory. Make it something meaningful to you. No special characters.
#This can typically be left as default: nameOfInstall="InstallPKG"
nameOfInstall="InstallPKG"

#Where is the PKG located?
pathToPKG=""

#TeamID value is optional, but recommended. If not in use, this should read: expectedTeamID=""
#Get this by running this command against your package: spctl -a -vv -t install /path/to/package.pkg
expectedTeamID=""

#MD5 value is optional, but recommended. If not in use, this should read: expectedMD5=""
#Get this by running this command against your package: md5 -q /path/to/package.pkg
expectedMD5=""

######################################
#
# Do not modify below for normal use 
#
######################################

scriptName=$(basename $0)


#################
#	Functions	#
#################

function verify_root_user()
{
	# check we are running as root
	if [[ $(id -u) -ne 0 ]]; then
	echo "ERROR: This script must be run as root **EXITING**"
	exit 1
	fi

}

function rm_if_exists()
{
    #Only rm something if the variable has a value and the thing exists!
    if [ -n "${1}" ] && [ -e "${1}" ];then
        rm -r "${1}"
    fi
}

#This function exits the script, deleting the temp files. first argument is the exit code, second argument is the message reported.
#example: cleanup_and_exit 1 "Download Failed."
function cleanup_and_exit()
{
	echo "${2}"
	rm_if_exists "$tmpDir"
	kill "$caffeinatepid" > /dev/null 2>&1
	exit "$1"
}

# Prevent the computer from sleeping while this is running, capture the PID of caffeinate so we can kill it in our exit function
function no_sleeping()
{

	/usr/bin/caffeinate -d -i -m -u &
	caffeinatepid=$!

}

# Used in debugging to give feedback via standard out
function debug_message()
{
#set +x
    if [ "$verboseMode" = 1 ]; then
    	/bin/echo "DEBUG: $*"
    fi
#set -x
}

# This is a report regarding the installation details that gets printed prior to the script actually running
function preinstall_summary_report()
{
	echo "$scriptName - $scriptVersion"
	echo "$(date '+%Y%m%dT%H%M%S%z'): "
	echo "Location: $pathToPKG"
	echo "Location Type: $pkgLocationType"
	echo "Expected MD5 is: $expectedMD5"
	echo "Expected TeamID is: $expectedTeamID"
	#If there is no TeamID and no MD5 verification configured print a warning
	if [ -z "$expectedTeamID" ] && [ -z "$expectedMD5" ]; then
		echo "**WARNING: No verification of the PKG before it is installed. Provide an MD5 or TeamID for better security and stability.**"
	fi
}

#This function will download the pkg (if it is hosted via url) and then verify the MD5 or TeamID if provided.
function download_pkg()
{
	# First, check if we have to download the PKG
	if [ "$pkgLocationType" = "url" ]; then
		pkgInstallerPath="$tmpDir"/"$nameOfInstall".pkg
		#Download installer to tmp folder
		curl -LJs "$pathToPKG" -o "$pkgInstallerPath"
		downloadResult=$?
		#Verify curl exited with 0
		if [ "$downloadResult" != 0 ]; then
			cleanup_and_exit 1 "Download failed. Exiting."
		fi
		debug_message "PKG downloaded successfully."
	else
		#If the PKG is a local file, set our installer path variable accordingly
		pkgInstallerPath="$pathToPKG"
	fi
}

function verify_pkg()
{
	# If an expectedMD5 was given, test against the actual installer and exit upon mismatch
	actualMD5="$(md5 -q "$pkgInstallerPath")"
	if [ -n "$expectedMD5" ] && [ "$actualMD5" != "$expectedMD5" ]; then
	cleanup_and_exit 1 "ERROR - MD5 mismatch. Exiting."
	fi

	# If an expectedTeamID was given, test against the actual installer and exit upon mismatch
	actualTeamID=$(spctl -a -vv -t install "$pkgInstallerPath" 2>&1 | awk -F '(' '/origin=/ {print $2 }' | tr -d ')' )
	# If an TeamID was given, test against the actual installer and exit upon mismatch
	if [ -n "$expectedTeamID" ] && [ "$actualTeamID" != "$expectedTeamID" ]; then
		cleanup_and_exit 1 "ERROR - TeamID mismatch. Exiting."
	fi

	#Lets take an opportunity to just verify that the PKG we're installing actually exists
	if [ ! -e "$pkgInstallerPath" ]; then
		cleanup_and_exit 1 "ERROR - PKG does not exist at this location: $pkgInstallerPath"
	fi

}

function install_pkg()
{
	#Run the pkg and capture output to variable in case of error
	installExitMessage=$( { installer -allowUntrusted -pkg "$pkgInstallerPath" -target / > "$tmpDir"/fail.txt; } 2>&1 )
	installResult=$?

	#Verify install exited with 0
	if [ "$installResult" != 0 ]; then
			cleanup_and_exit 1 "Installation command failed: $installExitMessage"
	fi

}

#################################
#	Validate and Process Input	#
#################################

# $1 - The first argument is the path to the PKG (either url or filepath). If no argument, fall back to script configuration.
if [ "$1" = "" ]; then
	debug_message "No PKG defined in command-line arguments, defaulting to script configuration"
else
	pathToPKG="${1}"
fi

# Look at the given path to PKG, and determine if its a local file path or a URL.
if [[ ${pathToPKG:0:4} == "http" ]]; then
	# The path to the PKG appears to be a URL.
	pkgLocationType="url"
elif [ -e "$pathToPKG" ]; then
	# The path to the PKG appears to exist on the local file system
	pkgLocationType="filepath"
else
	#Some kind of invalid input, not starting with a / or with http. Exit with an error
	cleanup_and_exit 1 "Path to PKG appears to be invalid or undefined."
fi

# $2 - The second argument is either an MD5 or a TeamID.
if [ "${2}" = "" ]; then
	debug_message "No Verification Value defined in command-line arguments, defaulting to script configuration"
elif [ ${#2} = 10 ]; then
	#The second argument is 10 characters, which indicates a TeamID.
	expectedTeamID="${2}"
elif [ ${#2} = 32 ]; then
	#The second argument is 10 characters, which indicates an MD5 hash
	expectedMD5="${2}"
else
	#There appears to be something wrong with the validation input, exit with an error
	cleanup_and_exit 1 "TeamID or MD5 passed at command line appear to be invalid. Expecting 10 characters for TeamID or 32 for MD5."
fi

# $3 - The third argument is either an MD5 or a TeamID.
if [ "${3}" = "" ]; then
	debug_message "Argument 3 is empty. Defaulting to script configuration"
elif [ ${#3} = 10 ]; then
	#The second argument is 10 characters, which indicates a TeamID.
	expectedTeamID="${3}"
elif [ ${#3} = 32 ]; then
	#The second argument is 10 characters, which indicates an MD5 hash
	expectedMD5="${3}"
else
	#There appears to be something wrong with the validation input, exit with an error
	cleanup_and_exit 1 "TeamID or MD5 passed at command line appear to be invalid. Expecting 10 characters for TeamID or 32 for MD5."
fi

##########################
# Script Starts Here	#
##########################

#Trap will hopefully run our exit function even if the script is cancelled or interrupted
trap cleanup_and_exit 1 2 3 6

#Make sure we're running with root privileges
verify_root_user

#Create a temporary working directory
tmpDir=$(mktemp -d /var/tmp/"$nameOfInstall".XXXXXX)

# Don't let the computer sleep until we're done
no_sleeping

#Print the preinstall Summary
preinstall_summary_report

#Download happens here, if needed
download_pkg

#MD5 and TeamID verification happens here
verify_pkg

#If we haven't exited yet, then the PKG was verified and we can install
install_pkg

#If we still haven't exited, that means there have been no failures detected. Cleanup and exit
cleanup_and_exit 0 "Installation successful"
