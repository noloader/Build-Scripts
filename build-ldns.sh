#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds LDNS from sources.

LDNS_TAR=ldns-1.7.1.tar.gz
LDNS_DIR=ldns-1.7.1
PKG_NAME=ldns

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= LDNS ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$LDNS_TAR" --ca-certificate="$GITHUB_CA_ZOO" \
     "https://www.nlnetlabs.nl/downloads/ldns/$LDNS_TAR"
then
    echo "Failed to download LDNS"
    exit 1
fi

rm -rf "$LDNS_DIR" &>/dev/null
gzip -d < "$LDNS_TAR" | tar xf -
cd "$LDNS_DIR" || exit 1

if [[ -e ../patch/ldns.patch ]]; then
    patch -u -p0 < ../patch/ldns.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-ed25519 \
    --enable-ed448 \
    --enable-rrtype-avc \
    --with-drill \
    --with-ssl="${INSTX_PREFIX}" \
    --with-ca-file="$INSTX_ICANN_FILE" \
    --with-ca-path="$INSTX_ICANN_PATH" \
    --with-trust-anchor="$INSTX_ROOTKEY_FILE"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure LDNS"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build LDNS"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test ldns"
echo

# 'make test' fails. The tarball is missing the test framework.
# Master is missing the source code for tpkg, and the test script
# accesses internal company URLs.
# https://github.com/NLnetLabs/ldns/issues/8
# https://github.com/NLnetLabs/ldns/issues/13
#MAKE_FLAGS=("test")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test LDNS"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################
# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$LDNS_TAR" "$LDNS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
