#!/bin/bash
#set -x

echo -n "Sophos Uninstall: "

sudo rm /Library/Sophos\ Anti-Virus/SophosSecure.keychain
sudo defaults write /Library/Preferences/com.sophos.sav TamperProtectionEnabled -bool false
sudo /Library/Application\ Support/Sophos/saas/Installer.app/Contents/MacOS/tools/InstallationDeployer --remove
SOPHOS_UNINSTALL_STATUS=$?
if [ $SOPHOS_UNINSTALL_STATUS != 0 ]; then
    /bin/echo "***WARNING*** SOPHOS DID NOT UNINSTALL SUCCESSFULLY ***WARNING***"
fi