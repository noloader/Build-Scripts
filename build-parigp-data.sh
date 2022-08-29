#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script installs PARI/GP data.

PARI_DATA_DIR=pari-data
PARI_PACKAGES=(elldata.tgz galpol.tgz seadata.tgz galdata.tgz)
PKG_NAME=pari-data

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
    echo ""
    echo "PARI/GP data is already installed."
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

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

# PARI/GP expects data at $datadir. See Install Guide
# and https://pari.math.u-bordeaux.fr/packages.html:
#
#   $ gp
#   ? default(datadir)
#   %1 = "/usr/local/share/pari"
#
# Packages should be named $datadir/elldata, $datadir/galdata, etc. Note:
# we have to strip a leading 'data/' after unpacking the tarball.

INSTX_DATADIR="${INSTX_PREFIX}/share/pari"
export INSTX_DATADIR

###############################################################################

echo ""
echo "========================================"
echo "============= PARI/GP data ============="
echo "========================================"

# Do all of this from a separate subdirectory
mkdir -p "${PARI_DATA_DIR}"
cd "${PARI_DATA_DIR}" || exit 1

echo ""
echo "**********************"
echo "Downloading packages"
echo "**********************"

for package in "${PARI_PACKAGES[@]}"
do
    echo "Downloading $package"
    if "${WGET}" -q -O "$package" --ca-certificate="${THE_CA_ZOO}" \
       "https://pari.math.u-bordeaux.fr/pub/pari/packages/$package"
    then
        if ! gzip -d < "$package" | tar xf -
        then
            echo "Failed to unpack $package"
        fi
    else
        echo "Failed to download $package"
    fi
done

echo ""
echo "**********************"
echo "Installing packages"
echo "**********************"

if [[ -n "${SUDO_PASSWORD}" ]];
then
    for package in "${PARI_PACKAGES[@]}"
    do
        package="${package%.*}"
        echo "Installing $package"
        printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S mv "$INSTX_DATADIR/$package" "$INSTX_DATADIR/$package.old" 2>/dev/null
        printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S mv "data/$package" "$INSTX_DATADIR"
        printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S rm -rf "$INSTX_DATADIR/$package.old"
    done

    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    for package in "${PARI_PACKAGES[@]}"
    do
        package="${package%.*}"
        echo "Installing $package"
        mv "$INSTX_DATADIR/$package" "$INSTX_DATADIR/$package.old" 2>/dev/null
        mv "data/$package" "$INSTX_DATADIR"
        rm -rf "$INSTX_DATADIR/$package.old"
    done

    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$PARI_DATA_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
