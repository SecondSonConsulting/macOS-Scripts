#!/bin/zsh

#Trevor Sysock (@BigMacAdmin) Second Son Consulting Inc.

#Gather the current OS build information. Pipe to xargs is used to trim leading whitespace
CURRENT_OS_BUILD=$(system_profiler SPSoftwareDataType | grep "System Version: " | xargs)

#Gather information regarding what beta enrollment channel this device is in.
BETA_CHECK=$(/System/Library/PrivateFrameworks/Seeding.framework/Resources/seedutil current)
BETA_RESULT=$(echo "${BETA_CHECK}" |grep "Currently enrolled in: ")


#Feedback/Report begins here
echo -n "${CURRENT_OS_BUILD}"

#Give a warning if the machine is part of a beta channel
if [ "Currently enrolled in: (null)" = "${BETA_RESULT}" ]; then
	echo " - Not enrolled in a beta channel."
else
	echo " - ***WARNING*** - THIS DEVICE IS ENROLLED IN A MACOS BETA CHANNEL ***WARNING***"
	echo "Beta Enrollment Details: "
	echo "${BETA_CHECK}"
fi