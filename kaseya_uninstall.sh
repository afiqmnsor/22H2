#!/bin/zsh
set -euo pipefail

# -----------------------------
# Root check
# -----------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo "Must be run as root"
  exit 1
fi

echo "Starting Kaseya VSA X agent removal..."

# -----------------------------
# Kill running processes
# -----------------------------
pkill -f KUsrTsk || true
pkill -f VSA || true
pkill -9 -f VSAHelper || true
pkill -9 -f VSAUpdateHelper || true
pkill -9 -f VSACommandHelper || true
pkill -9 -f agentmon || true
pkill -9 -f endpoint || true

# -----------------------------
# Unload LaunchDaemons
# -----------------------------
launchctl bootout system /Library/LaunchDaemons/com.kaseya.agentmon.plist 2>/dev/null || true
launchctl bootout system /Library/LaunchDaemons/com.kaseya.endpoint.plist 2>/dev/null || true
launchctl bootout system /Library/LaunchDaemons/com.kaseya.VSAHelper.plist 2>/dev/null || true
launchctl bootout system /Library/LaunchDaemons/com.kaseya.VSAUpdateHelper.plist 2>/dev/null || true
launchctl bootout system /Library/LaunchDaemons/com.kaseya.VSACommandHelper.plist 2>/dev/null || true

# -----------------------------
# Unload LaunchAgents (logged-in user, not root)
# -----------------------------
CONSOLE_UID=$(stat -f %u /dev/console)
if [[ "$CONSOLE_UID" -ne 0 ]]; then
  launchctl bootout gui/$CONSOLE_UID /Library/LaunchAgents/com.kaseya.* 2>/dev/null || true
fi

sleep 3

# -----------------------------
# Vendor uninstall (all known paths)
# -----------------------------
for EP in \
  /Library/Kaseya/Endpoint/KaseyaEndpoint \
  "/Library/Application Support/com.kaseya/Endpoint/KaseyaEndpoint"
do
  if [[ -x "$EP" ]]; then
    "$EP" --uninstallAll || true
  fi
done

# -----------------------------
# File & directory cleanup
# -----------------------------
rm -rf \
  /Applications/KUsrTsk.app \
  "/Applications/VSA X.app" \
  /Library/Kaseya \
  "/Library/Application Support/com.kaseya" \
  /Library/Logs/Kaseya \
  /Library/Logs/com.kaseya \
  /Library/Caches/com.kaseya \
  /Library/PrivilegedHelperTools/com.kaseya.* \
  /Library/Preferences/kaseyad.* \
  /Library/Preferences/Network/com.kaseya.AgentMon.plist \
  /Library/LaunchDaemons/com.kaseya.* \
  /Library/LaunchAgents/com.kaseya.* \
  /private/var/db/receipts/com.kaseya.* \
  /private/var/folders/*/*/com.kaseya* \
  /var/tmp/com.kaseya* \
  /var/tmp/kas* \
  /var/tmp/kpid \
  /var/tmp/kstopmsg.txt \
  /var/tmp/kperfmon.txt \
  /var/tmp/KASetup.log \
  /var/tmp/lastChk.txt \
  /var/tmp/.pkg* \
  /var/tmp/.mpkg* \
  /var/tmp/kmaconfigup \
  /var/tmp/kmapkgprompt \
  /var/tmp/kmaupdater \
  /var/tmp/.exe \
  /var/tmp/.tif \
  /var/tmp/kasmbios.txt \
  /var/tmp/updatekini

# -----------------------------
# Forget package receipts (prevents reinstall / inventory issues)
# -----------------------------
pkgutil --forget com.kaseya.agentmon 2>/dev/null || true
pkgutil --forget com.kaseya.endpoint 2>/dev/null || true
pkgutil --forget com.kaseya.vsa 2>/dev/null || true
pkgutil --forget com.kaseya.* 2>/dev/null || true

# -----------------------------
# Verification
# -----------------------------
if pgrep -f kaseya >/dev/null; then
  echo "WARNING: Kaseya processes still running"
  exit 1
else
  echo "Kaseya VSA X fully removed"
fi

exit 0
