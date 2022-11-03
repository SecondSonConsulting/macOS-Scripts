#!/bin/bash

#Written by Trevor Sysock, Second Son Consulting
#v. 1.0

FDE_STATUS=$(fdesetup status)
ESCROW_PLIST="/var/db/ConfigurationProfiles/Settings/com.apple.security.FDERecoveryKeyEscrow.plist"

echo -n "$FDE_STATUS "

if [ "FileVault is On." != "$FDE_STATUS" ]; then
	exit 0
fi

if [ -a "$ESCROW_PLIST" ]; then
	echo "Key Set to be Escrowed to: $(defaults read "$ESCROW_PLIST" Location)"
else
	echo "KEY NOT ESCROWED"
fi

exit 0