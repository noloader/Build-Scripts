#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Crypto++ library from sources.

CRYPTOPP_VER=840
CRYPTOPP_ZIP=cryptopp${CRYPTOPP_VER}.zip
CRYPTOPP_DIR=cryptopp${CRYPTOPP_VER}
PKG_NAME=cryptopp

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then

    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
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

echo ""
echo "========================================"
echo "============== Crypto++ ================"
echo "========================================"

echo "Current shell id: $BASHPID"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CRYPTOPP_ZIP" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.cryptopp.com/$CRYPTOPP_ZIP"
then
    echo "Failed to download Crypto++"
    exit 1
fi

rm -rf "$CRYPTOPP_DIR" &>/dev/null
unzip -oq "$CRYPTOPP_ZIP" -d "$CRYPTOPP_DIR"
cd "$CRYPTOPP_DIR"

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "$INSTX_CPPFLAGS" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "$INSTX_ASFLAGS" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("all" "libcryptopp.pc" "-j" "${INSTX_JOBS}")
if ! CPPFLAGS="${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Crypto++"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

if ! ./cryptest.exe v
then
    echo "Failed to test Crypto++"
    exit 1
fi

if ! ./cryptest.exe tv all
then
    echo "Failed to test Crypto++"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=${INSTX_PREFIX}" "LIBDIR=${INSTX_LIBDIR}")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "$CURR_DIR" || exit 1

# Test from install directory
if ! "${INSTX_PREFIX}/bin/cryptest.exe" v
then
    echo "Failed to test Crypto++"
    exit 1
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "$INSTX_PKG_CACHE/$PKG_NAME"

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$CRYPTOPP_ZIP" "$CRYPTOPP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
