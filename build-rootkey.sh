#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several files needed by DNSSEC
# and libraries like Unbound and LDNS.

PKG_NAME=rootkey

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "${INSTX_PKG_CACHE}/${PKG_NAME}" ]]; then
    #echo ""
    #echo "$PKG_NAME is already installed."
    exit 0
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

echo ""
echo "========================================"
echo "============ ICANN Root CAs ============"
echo "========================================"

BOOTSTRAP_ICANN_FILE="bootstrap/icannbundle.pem"

if [[ -n "${SUDO_PASSWORD}" ]]
then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S mkdir -p "$INSTX_ICANN_PATH"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "$BOOTSTRAP_ICANN_FILE" "$INSTX_ICANN_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S chmod u=rw,g=r,o=r "$INSTX_ICANN_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash"${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    mkdir -p "$INSTX_ICANN_PATH"
    cp "$BOOTSTRAP_ICANN_FILE" "$INSTX_ICANN_FILE"
    chmod u=rw,g=r,o=r "$INSTX_ICANN_FILE"
    bash"${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "========================================"
echo "============ DNS Root Keys ============="
echo "========================================"

BOOTSTRAP_ROOTKEY_FILE="bootstrap/dnsrootkey.pem"

if [[ -n "${SUDO_PASSWORD}" ]]
then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S mkdir -p "$INSTX_ROOTKEY_PATH"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S rm -f "$INSTX_ROOTKEY_PATH/dnsroot.key"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "$BOOTSTRAP_ROOTKEY_FILE" "$INSTX_ROOTKEY_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S chmod u=rw,g=r,o=r "$INSTX_ROOTKEY_FILE"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash"${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    mkdir -p "$INSTX_ROOTKEY_PATH"
    rm -f "$INSTX_ROOTKEY_PATH/dnsroot.key"
    cp "$BOOTSTRAP_ROOTKEY_FILE" "$INSTX_ROOTKEY_FILE"
    chmod u=rw,g=r,o=r "$INSTX_ROOTKEY_FILE"
    bash"${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "You should create a cron job that runs unbound-anchor on a"
echo "regular basis to update $INSTX_ROOTKEY_FILE"
echo "*****************************************************************************"
echo ""

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

exit 0
