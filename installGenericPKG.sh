#!/bin/bash
#set -x

##Written by Trevor Sysock (aka @bigmacadmin) at Second Son Consulting Inc.
#
#Usage:
# Can be run as a Mosyle Custom Command or locally.
# Any other step in the script that fails will produce an easily read error report to standard output.
# Uncomment set -x above for advanced debugging

######################################
#
# User Configuration
#
######################################

#Name for this job (this is just for you, name it something meaningful for the purpose. No special chars.
userInputName="InstallPKG"

#Where is the PKG hosted?
predefinedURL=""

#MD5 value is optional, but recommended
expectedMD5=""

######################################
#
# Do not modify below for normal use 
#
######################################

#This function exits the script, deleting the temp files. first argument is the exit code, second argument is the message reported.
#example: cleanup_and_exit 1 "Download Failed."
function cleanup_and_exit()
{
echo "$2"
rm -r "$tmpDir"
exit "$1"
}

if [ "$1" = "" ]; then
	nameOfInstall="$userInputName"
else
	nameOfInstall="$1"
fi

if [ "$2" = "" ]; then
	#Path to the PKG you wish to install
	downloadURL="$predefinedURL"
else
	downloadURL="$2"
fi

#Make tmp folder
tmpDir=$(mktemp -d /var/tmp/"$nameOfInstall".XXXXXX)

#Path to pkg being downloaded
pkgFullPath="$tmpDir"/"$nameOfInstall".pkg

#Download installer to tmp folder
curl -LJs "$downloadURL" -o "$pkgFullPath"
downloadResult=$?

#Verify curl exited with 0
if [ "$downloadResult" != 0 ]; then
	cleanup_and_exit 1 "Download failed. Exiting."
fi

#If there is an expected md5 and it does not match, then exit
if [ -n "$expectedMD5" ] && [ "$(md5 -q "$pkgFullPath")" != "$expectedMD5" ]; then
	cleanup_and_exit 1 "ERROR - MD5 mismatch. Exiting."
fi

#Run the installer and capture output to variable in case of error
installExitMessage=$( { installer -allowUntrusted -pkg "$pkgFullPath" -target / > "$tmpDir"/fail.txt; } 2>&1 )
installResult=$?

#Verify install exited with 0
if [ "$installResult" != 0 ]; then
        cleanup_and_exit 1 "Install or Download failed: $installExitMessage"
fi

#No failures. Cleanup and exit
cleanup_and_exit 0 "$(date): Installation successful"
