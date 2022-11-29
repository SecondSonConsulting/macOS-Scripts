#!/bin/bash
#set -x

##Written by Trevor Sysock (aka @bigmacadmin) at Second Son Consulting Inc.
#
#Usage:
# Change the "downloadURL" variable to match the specific Sophos environment you are installing for.
# Can be run as a Mosyle Custom Command or locally.
# If Sophos is already installed, the installer errors out.
# Any other step in the script that fails will produce an easily read error report to standard output.
# Find "YOUR_SOPHOS_URL" by using developer tools in your browser to identify the URL when you click the "Protect Devices" download

######################################
#
# User Configuration
#
######################################

#Every Sophos environment needs its own unique URL.
#If using the Mosyle CDN variable, you can omit the "quotation marks"
#This can be passed as an argument, or defined in the script. If there's a conflict, the one passed as an argument wins.
downloadURL=""

if [[ ${1:0:4} == "http" ]]; then
	# Appears a URL was passed as a script argument. Setting the downloadURL accordingly.
	downloadURL="${1}"
fi

######################################
#
# Do not modify below for normal use 
#
######################################

function cleanup_and_exit()
{
rm -r "$tmpDir"
exit $@
}

#Make tmp folder
tmpDir=$(mktemp -d /var/tmp/SSC-SophosInstall.XXXXXX)

#Declare primary working directory
installDir="$tmpDir/SophosInstall"

#Check if the downloadURL was actually provided
if [ -z $downloadURL ]; then
	echo "ERROR: No download URL provided"
	cleanup_and_exit 1
fi

#Download installer to tmp folder
curl -LJs "$downloadURL" -o "$tmpDir"/SophosInstall.zip
downloadResult=$?

#Verify curl exited with 0
if [ "$downloadResult" != 0 ]; then
	echo "Download failed. Exiting."
	cleanup_and_exit 1
fi

#Unzip silently to tmp dir
unzip -qq "$installDir".zip -d "$installDir"
unzipResult=$?

#Verify unzip exited with 0
if [ "$unzipResult" != 0 ]; then
        echo "Unzip failed. Exiting."
        cleanup_and_exit 1
fi

#Verify TeamIdentifier matches the expected

expectedTeamID='TeamIdentifier=2H5GFH3774'
actualTeamID=$(codesign -dv "$installDir/Sophos Installer.app" 2>&1 | grep "TeamIdentifier")

if [[ "$expectedTeamID" != "$actualTeamID" ]]; then
	echo "Verification Failed"
	echo "Expected Team Identifier: $expectedTeamID"
	echo "Actual Team Identifier: $actualTeamID"
	cleanup_and_exit 1
fi

#Set executables
chmod a+x "$installDir/Sophos Installer.app/Contents/MacOS/Sophos Installer"
chmod a+x "$installDir/Sophos Installer.app/Contents/MacOS/tools/com.sophos.bootstrap.helper"

#Run the installer and capture output to variable in case of error
sophosExitMessage=$( { "$installDir/Sophos Installer.app/Contents/MacOS/Sophos Installer" --install > "$tmpDir"/fail.txt; } 2>&1 )
installResult=$(echo $?)
#Verify install exited with 0
if [ "$installResult" != 0 ]; then
        echo "Install failed."
        echo "$sophosExitMessage"
        cleanup_and_exit 1
fi

#No failures. Cleanup and exit
echo "Success"
cleanup_and_exit 0
