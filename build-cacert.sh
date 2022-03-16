#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several Root CA certifcates needed
# for other scripts and wget downloads over HTTPS.

PKG_NAME=cacert

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

# The password should die when this subshell goes out of scope
if [[ "${SUDO_PASSWORD_DONE}" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

# setup-cacert.sh writes the certs locally for the user so we
# can download cacerts.pem using cURL or Wget. build-cacert.sh
# installs cacerts.pem in ${INSTX_CACERT_PATH}. Programs like
# cURL, Git and Wget use cacerts.pem.
if [[ ! -e "$HOME/.build-scripts/cacert/cacert.pem" ]]; then
    # Hide output to cut down on noise.
    ./setup-cacerts.sh &>/dev/null
fi

# Line 4 is a date/time stamp
bootstrap_cacert="$(sed '4!d' "bootstrap/cacert.pem" 2>/dev/null | cut -b 40- | awk '$1=$1')"
installed_cacert="$(sed '4!d' "$INSTX_CACERT_FILE" 2>/dev/null | cut -b 40- | awk '$1=$1')"

# Wipe installed if the key is not present
if [[ ! -f "${INSTX_PKG_CACHE}/${PKG_NAME}" ]]; then
    installed_cacert=""
fi

if [[ -z "${installed_cacert}" ]]; then
    installed_cacert="Not available"
fi

# The bootstrap cacert.pem is the latest
if [[ "$bootstrap_cacert" == "$installed_cacert" ]]; then
    #echo ""
    #echo "$PKG_NAME is already installed."
    exit 0
fi

###############################################################################

echo ""
echo "========================================"
echo "=========== Mozilla Root CAs ==========="
echo "========================================"

echo ""
echo "Installing cacert.pem"
echo "  installed: ${installed_cacert}"
echo "  available: ${bootstrap_cacert}"

BOOTSTRAP_CACERT_FILE="${INSTX_TOPDIR}/bootstrap/cacert.pem"
FIX_PERMISSIONS="${INSTX_TOPDIR}/fix-permissions.sh"

if [[ -n "${SUDO_PASSWORD}" ]]
then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S mkdir -p "$INSTX_CACERT_PATH"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "$BOOTSTRAP_CACERT_FILE" "$INSTX_CACERT_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S chmod u=rw,go=r "$INSTX_CACERT_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash ${FIX_PERMISSIONS} "${INSTX_PREFIX}"
else
    mkdir -p "$INSTX_CACERT_PATH"
    cp "$BOOTSTRAP_CACERT_FILE" "$INSTX_CACERT_FILE"
    chmod u=rw,go=r "$INSTX_CACERT_FILE"
    bash ${FIX_PERMISSIONS} "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

###############################################################################

exit 0
