#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libexosip2 from sources.

# Sources available at
# http://download.savannah.nongnu.org/releases/exosip

OSIP2_TAR=libexosip2-5.1.2.tar.gz
OSIP2_DIR=libexosip2-5.1.2
PKG_NAME=libexosip2

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

# c-ares needs a C++11 compiler
if [[ "$INSTX_CXX11" -ne 0 ]]
then
    ENABLE_CARES=1
else
    ENABLE_CARES=0
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

if [[ "$ENABLE_CARES" -eq 1 ]]
then
    if ! ./build-cares.sh
    then
        echo "Failed to build c-ares"
        exit 1
    fi
fi

###############################################################################

if ! ./build-ucommon.sh
then
    echo "Failed to build uCommon"
    exit 1
fi

###############################################################################

if ! ./build-libosip2-rc.sh
then
    echo "Failed to build libosip2"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "============== libeXosip2 =============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "$WGET" -q -O "$OSIP2_TAR" --ca-certificate="$THE_CA_ZOO" \
     "https://sip.antisip.com/tmp//$OSIP2_TAR"
then
    echo "Failed to download libeXosip2"
    exit 1
fi

rm -rf "$OSIP2_DIR" &>/dev/null
gzip -d < "$OSIP2_TAR" | tar xf -
cd "$OSIP2_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/libexosip2-rc.patch ]]; then
    patch -u -p0 < ../patch/libexosip2-rc.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "***************************"
echo "Configuring package"
echo "***************************"

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
    --enable-openssl

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libeXosip2"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-k" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libeXosip2"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to test libeXosip2"
    echo "***************************"
    exit 1
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo "***************************"
echo "Installing package"
echo "***************************"

MAKE_FLAGS=("install" "V=1")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$OSIP2_TAR" "$OSIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
