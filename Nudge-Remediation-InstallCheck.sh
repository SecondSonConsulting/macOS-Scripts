#!/bin/zsh --no-rcs
# shellcheck shell=bash
#set -x

# Nudge-Remediation-InstallCheck.sh by: Trevor Sysock (aka @bigmacadmin) at Second Son Consulting Inc.
# 2024-08-18 - updated and published 2025-08-29
# v.2.1

#  Copyright (c) 2025 Second Son Consulting
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

# Usage: This script will run the `remediation_needed` function if any aspect of Nudge is not configured correctly.
#  - Default is to exit 1 for use with a Munki installcheck_script
#  - Complete the details in the Configuration section to fit your environment

# Nudge by Erik Gomez and Mac Admins Open Source: https://github.com/macadmins/nudge

#####################
#   Configuration   #
#####################

# Change `checkForLogger` to false if you do not use the logger daemon
checkForLogger=true
#checkForLogger=false

# This function runs when a problem is found that requires remediation
remediation_needed(){
    exit 0
}

# This function is run if Nudge looks healthy
no_remediation_needed(){
    exit 1
}

####################################
# DO NOT EDIT BELOW FOR NORMAL USE #
####################################
# Syntax:
#   Variables and arrays are "camel case": $thisIsAVariable
#   Functions are "snake case": this_is_a_function
#   Functions are declared with the declaration of "function this_is_a_function(){}"

#################
#   Variables   #
#################
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
uid=$(id -u "$currentUser" 2> /dev/null)

expectedTeamID="T4SK8ZXCXG"

#################
#   Functions   #
#################
# convenience function to run a command as the current user
# usage:
#   runAsUser command arguments...
runAsUser() {  
  # shellcheck disable=SC2236
  if [ "$currentUser" != "loginwindow" ] && [ ! -z "$currentUser" ]; then
    launchctl asuser "$uid" sudo -u "$currentUser" "$@"
  else
    echo "No user logged in"
    exit 0
  fi
}

##########################
#   Script Starts Here   #
##########################
# If Nudge isn't installed, then exit no remediation needed (because munki should pick up the need to install natively)
if [[ ! -d "/Applications/Utilities/Nudge.app" ]]; then
    no_remediation_needed
fi

# Verify that the logger daemon is running, only if we're checking for it, and if not then we need remediation
if [[ "$checkForLogger" == "true" ]] && ! launchctl list | grep -qi 'com.github.macadmins.Nudge.Logger' ; then
    remediation_needed
fi

# If the LaunchAgent doesn't exist, then we need remediation
if ! [ -f "/Library/LaunchAgents/com.github.macadmins.Nudge.plist" ]; then
    remediation_needed
fi

# If the LaunchAgent isn't calling Nudge, then we need remediation
if ! /usr/libexec/PlistBuddy -c "Print :ProgramArguments" /Library/LaunchAgents/com.github.macadmins.Nudge.plist | grep -qi "/Applications/Utilities/Nudge.app/Contents/MacOS/Nudge"; then
    remediation_needed
fi

# Get the Nudge Team ID and compare it to the expected value, if they don't match then we need remediation
actualTeamID=$(codesign -dv /Applications/Utilities/Nudge.app/ 2>&1 | awk -F '=' '/^TeamIdentifier=/ {print $NF}')

if [ "$actualTeamID" != "$expectedTeamID" ]; then
    remediation_needed
fi

# Verify we're not at the login window or setup window and that we have a value for the currently logged in user, otherwise exit now
if [ "$currentUser" = "loginwindow" ] || [ "$currentUser" = "_mbsetupuser" ] || [ -z "$currentUser" ]; then
    no_remediation_needed
fi

# Verify that the launch agent is running for the logged in user, if not then we need remediation.
if ! runAsUser launchctl list | grep -qi 'com.github.macadmins.Nudge'; then
    remediation_needed
fi

no_remediation_needed
