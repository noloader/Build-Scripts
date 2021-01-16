#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script creates directories in $prefix. A couple
# of the packages are braindead and create files instead
# of directories.

echo ""
echo "**********************"
echo "Creating directories"
echo "**********************"

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

# Try to locate fix-permissions.sh script
if [[ -f ../../fix-permissions.sh ]]; then
    FIX_PERMISSIONS="../../fix-permissions.sh"
elif [[ -f ../../fix-permissions.sh ]]; then
    FIX_PERMISSIONS="../fix-permissions.sh"
elif [[ -f ../../fix-permissions.sh ]]; then
    FIX_PERMISSIONS="./fix-permissions.sh"
else
    FIX_PERMISSIONS="fix-permissions.sh"
fi

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S mkdir -p "${INSTX_PREFIX}/"{bin,sbin,etc,include,var,libexec,share}
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S mkdir -p "${INSTX_PREFIX}/share/"{doc,info,man}
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S mkdir -p "${INSTX_PKGCONFIG}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ${FIX_PERMISSIONS} "${INSTX_PREFIX}"
else
    mkdir -p "${INSTX_PREFIX}/"{bin,sbin,etc,include,var,libexec,share,src}
    mkdir -p "${INSTX_PREFIX}/share/"{doc,info,man}
    mkdir -p "${INSTX_PKGCONFIG}"
    bash ${FIX_PERMISSIONS} "${INSTX_PREFIX}"
fi

exit 0
