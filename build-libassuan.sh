#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libassuan from sources.

LIBASSUAN_VER=2.5.4
LIBASSUAN_TAR="libassuan-${LIBASSUAN_VER}.tar.bz2"
LIBASSUAN_DIR="libassuan-${LIBASSUAN_VER}"
PKG_NAME=libassuan

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

if ! ./build-gpgerror.sh
then
    echo "Failed to build libgpg-error"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== libassuan =============="
echo "========================================"

echo ""
echo "*****************************"
echo "Downloading package"
echo "*****************************"

if ! "$WGET" -q -O "$LIBASSUAN_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/libassuan/$LIBASSUAN_TAR"
then
    echo "*****************************"
    echo "Failed to download libassuan"
    echo "*****************************"
    exit 1
fi

rm -rf "$LIBASSUAN_DIR" &>/dev/null
tar xjf "$LIBASSUAN_TAR"
cd "$LIBASSUAN_DIR"

# cp tests/Makefile.in tests/Makefile.in.orig

if [[ -e ../patch/libassuan.patch ]]; then
    patch -u -p0 < ../patch/libassuan.patch
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
    --with-libgpg-error-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo "*****************************"
    echo "Failed to configure libassuan"
    echo "*****************************"
    bash ../collect-logs.sh
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
    echo "*****************************"
    echo "Failed to build libassuan"
    echo "*****************************"
    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "*****************************"
echo "Testing package"
echo "*****************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "*****************************"
    echo "Failed to test libassuan"
    echo "*****************************"
    bash ../collect-logs.sh
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

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$LIBASSUAN_TAR" "$LIBASSUAN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0