#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libtasn1 from sources.

TASN1_VER=4.18.0
TASN1_TAR=libtasn1-${TASN1_VER}.tar.gz
TASN1_DIR=libtasn1-${TASN1_VER}
PKG_NAME=libtasn1

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

echo ""
echo "========================================"
echo "=============== libtasn1 ==============="
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

if ! "$WGET" -q -O "$TASN1_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/libtasn1/$TASN1_TAR"
then
    echo "Failed to download libtasn1"
    exit 1
fi

rm -rf "$TASN1_DIR" &>/dev/null
gzip -d < "$TASN1_TAR" | tar xf -
cd "$TASN1_DIR" || exit 1

cp lib/decoding.c lib/decoding.c.orig
cp src/Makefile.am src/Makefile.am.orig

if [[ -e ../patch/libtasn1.patch ]]; then
    patch -u -p0 < ../patch/libtasn1.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "****************************"
echo "Configuring package"
echo "****************************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    tasn1_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${TASN1_DIR}"
    tasn1_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${TASN1_DIR}"
else
    tasn1_cflags="${INSTX_CFLAGS}"
    tasn1_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${tasn1_cflags}" \
    CXXFLAGS="${tasn1_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-shared \
    --disable-doc

if [[ "$?" -ne 0 ]]; then
    echo "****************************"
    echo "Failed to configure libtasn1"
    echo "****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "****************************"
echo "Building package"
echo "****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "****************************"
    echo "Failed to build libtasn1"
    echo "****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "****************************"
echo "Testing package"
echo "****************************"

# For NetBSD and failed self tests.
LD_LIBRARY_PATH="$PWD/lib/.libs:$LD_LIBRARY_PATH"
LD_LIBRARY_PATH=$(echo -n "$LD_LIBRARY_PATH" | sed 's/:$//')
export LD_LIBRARY_PATH

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "****************************"
    echo "Failed to build libtasn1"
    echo "****************************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

echo "****************************"
echo "Installing package"
echo "****************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${TASN1_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${TASN1_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$TASN1_TAR" "$TASN1_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
