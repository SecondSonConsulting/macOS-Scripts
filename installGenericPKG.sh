#!/bin/bash
#set -x

verboseMode=false

scriptVersion="v2.4"

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
# Uncomment set -x and/or verboseMode=true at the top of the script for advanced debugging

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

# Additional features have been added since the original release. These features are not supported 
# when using command line arguments, and must be configured within the script

# Package Identifier. 
    # If you fill out this option, you also must fill out the pkgVersion option.
    # If this option is included, the script will exit if the same version of this pkg has already been successfully installed on the device.
    # The script only prevents install if the expectedPackageVersion is an exact match.
    # Example: expectedPackageID="com.secondsonconsulting.pkg.Renew" expectedPackageVersion="1.0.1"

# Package in Zip
    # This script supports pkgs contained within a .zip
    # Some packages use the old style bundle format (such as Adobe CC custom PKGs) and this doesn't play well with curl, etc.
    # Set the pkgInZip=true option to add steps to unzip the download prior to running the package contained within
    # When using the expectedMD5 validation option in conjunciton with pkgInZip, you MUST specify the md5 checksum of the .zip file, not the pkg within
    # TeamID is still supported with pkgInZip, and will be checked against the package after being unzipped
	# DO NOT include multiple pkgs in your zip file. Other files can be bundled in the zip, and will be unzipped right beside your pkg

######################################
#
# User Configuration
#
######################################

# This is low consequence, and only used for the temp directory. Make it something meaningful to you. No special characters.
# This can typically be left as default: nameOfInstall="InstallPKG"
nameOfInstall="InstallPKG"

# Where is the PKG located?
pathToPKG=""

# Is this PKG inside a .zip? Must be either true or false or unset
#pkgInZip=true
pkgInZip=false

# TeamID value is optional, but recommended. If not in use, this should read: expectedTeamID=""
# Get this by running this command against your package: spctl -a -vv -t install /path/to/package.pkg
expectedTeamID=""

# MD5 value is optional, but recommended. If not in use, this should read: expectedMD5=""
# Get this by running this command against your package: md5 -q /path/to/package.pkg
expectedMD5=""

# Package Identifier and Expected Version. If the device already has a receipt for this package ID for the specified version, script will exit
expectedPackageID=""

expectedPackageVersion=""

######################################
#
# Do not modify below for normal use 
#
######################################

scriptName=$(basename "$0")

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
    if "$verboseMode"; then
    	/bin/echo "DEBUG: $*"
    fi
#set -x
}

# Check if the specified expectedPackageID and version have already run on this machine
function check_package_receipt(){
	# If the expectedPackageID variable is not empty
	if [ ! -z "$expectedPackageID" ] || [ ! -z "$expectedPackageVersion" ];then
		# Verify a version has also been included. Otherwise, exit with an error (this is a misconfiguration)
		if [ -z "$expectedPackageID" ] || [ -z "$expectedPackageVersion" ]; then
			cleanup_and_exit 1 "ERROR: Misconfiguration. Both expectedPackageID and expectedPackageVersion are required if using that feature."
		fi
		# Check the receipts and get the version if it exists
		installedPackageVersion=$(/usr/libexec/PlistBuddy -c 'Print :pkg-version' /dev/stdin <<< "$(pkgutil --pkg-info-plist "$expectedPackageID" 2> /dev/null)" 2> /dev/null)
		# Check if the install is not needed
		if [[ "$installedPackageVersion" == "$expectedPackageVersion" ]]; then
			echo "$scriptName - $scriptVersion"
			echo "$(date '+%Y%m%dT%H%M%S%z'): "
			echo "Package ID $expectedPackageID is already on $expectedPackageVersion no action needed"
			cleanup_and_exit 0 "Success"
		else
            echo "No receipt for $expectedPackageID $expectedPackageVersion - Proceeding with install"
        fi
	else
		echo "No Package ID defined"
	fi
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
	# First, check if we're downloading a pkg or a zip
	if [ ! -z $pkgInZip ] && $pkgInZip; then
		downloadFileType="zip"
	else
		downloadFileType="pkg"
	fi
	# Next, check if we have to download the PKG
	if [ "$pkgLocationType" = "url" ]; then
		pkgInstallerPath="$tmpDir"/"$nameOfInstall.$downloadFileType"
		#Download installer to tmp folder
		curl -LJs "$pathToPKG" -o "$pkgInstallerPath"
		downloadResult=$?
		#Verify curl exited with 0
		if [ "$downloadResult" != 0 ]; then
			cleanup_and_exit 1 "Download failed. Exiting."
		fi
		debug_message "Download completed."
	else
		#If the PKG is a local file, set our installer path variable accordingly
		pkgInstallerPath="$pathToPKG"
	fi
}

function unzip_the_download(){
	ditto -x -k "$pkgInstallerPath" "$tmpDir"
	dittoResult=$?
	#Verify ditto exited with 0
	if [ "$dittoResult" != 0 ]; then
		cleanup_and_exit 1 "Ditto/Unzip failed. Exiting."
	fi
	pkgInstallerPath=$(find "$tmpDir" -name "*.pkg")

}

function check_md5(){
    # If an expectedMD5 was given, test against the actual installer and exit upon mismatch
	actualMD5=$(md5 -q "$pkgInstallerPath" 2>/dev/null)
	if [ -n "$expectedMD5" ] && [ "$actualMD5" != "$expectedMD5" ]; then
	cleanup_and_exit 1 "ERROR - MD5 mismatch. Exiting."
	fi


}

function verify_pkg()
{
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

#Print the preinstall Summary
preinstall_summary_report

# Check whether this package has already been successfully installed
check_package_receipt

#Create a temporary working directory
tmpDir=$(mktemp -d /var/tmp/"$nameOfInstall".XXXXXX)

# Don't let the computer sleep until we're done
no_sleeping

#Download happens here, if needed
download_pkg

#MD5 verification happens here
check_md5

# If the PKG is in a zip, unzip it
if [ ! -z $pkgInZip ] && $pkgInZip; then
    unzip_the_download
fi

#TeamID verification happens here
verify_pkg

#If we haven't exited yet, then the PKG was verified and we can install
install_pkg

#If we still haven't exited, that means there have been no failures detected. Cleanup and exit
cleanup_and_exit 0 "Success"
