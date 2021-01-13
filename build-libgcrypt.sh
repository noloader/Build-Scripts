#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libgcrypt from sources.

GCRYPT_VER=1.8.7
GCRYPT_TAR="libgcrypt-${GCRYPT_VER}.tar.bz2"
GCRYPT_DIR="libgcrypt-${GCRYPT_VER}"
GCRYPT_LOG="libgcrypt.log"
PKG_NAME=libgcrypt

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

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgpg-error"
    exit 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== libgcrypt =============="
echo "========================================"

echo ""
echo "*****************************"
echo "Downloading package"
echo "*****************************"

echo ""
echo "libgcrypt ${GCRYPT_VER}..."

if ! "$WGET" -q -O "$GCRYPT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/libgcrypt/$GCRYPT_TAR"
then
    echo "Failed to download libgcrypt"
    exit 1
fi

rm -rf "$GCRYPT_DIR" &>/dev/null
tar xjf "$GCRYPT_TAR"
cd "$GCRYPT_DIR"

# cp tests/Makefile.in tests/Makefile.in.orig

if [[ -e ../patch/libgcrypt.patch ]]; then
    patch -u -p0 < ../patch/libgcrypt.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "*****************************"
echo "Configuring package"
echo "*****************************"

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
    --enable-shared \
    --with-libgpg-error-prefix="${INSTX_PREFIX}" \
    --with-pth-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo "*****************************"
    echo "Failed to configure libgcrypt"
    echo "*****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "*****************************"
echo "Building package"
echo "*****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libgcrypt"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "*****************************"
echo "Testing package"
echo "*****************************"

# libgcrypt fails random tests on OS X. Allow one failure
# in random due to SIP. Also see https://dev.gnupg.org/T5009.

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}" 2>&1 | tee "${GCRYPT_LOG}"
then
    echo "*****************************"
    echo "Failed to test libgcrypt (1)"
    echo "*****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

errors=$(grep 'FAIL: ' "${GCRYPT_LOG}" | grep -c -v 'FAIL: random')
if [ "$errors" -gt 0 ];
then
    echo "*****************************"
    echo "Failed to test libgcrypt (2)"
    echo "*****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix runpaths
bash ../fix-runpath.sh

echo "*****************************"
echo "Installing package"
echo "*****************************"

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

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GCRYPT_LOG" "$GCRYPT_TAR" "$GCRYPT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
