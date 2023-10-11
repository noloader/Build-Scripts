#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libgcrypt from sources.

GCRYPT_VER=1.10.2
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

if ! "${WGET}" -q -O "$GCRYPT_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://gnupg.org/ftp/gcrypt/libgcrypt/$GCRYPT_TAR"
then
    echo "Failed to download libgcrypt"
    exit 1
fi

rm -rf "$GCRYPT_DIR" &>/dev/null
tar xjf "$GCRYPT_TAR"
cd "$GCRYPT_DIR"

if [[ -e ../patch/libgcrypt.patch ]]; then
    echo ""
    echo "****************************"
    echo "Patching package"
    echo "****************************"

    patch -u -p0 < ../patch/libgcrypt.patch
fi

is_apple_m1=$(sysctl machdep.cpu.brand_string 2>&1 | grep -i -c 'Apple M1')
if [[ "${is_apple_m1}" -eq 1 ]]; then
    if [[ -e ../patch/libgcrypt-darwin.patch ]]; then
        echo ""
        echo "****************************"
        echo "Patching package (Darwin)"
        echo "****************************"

        patch -u -p0 < ../patch/libgcrypt-darwin.patch
    fi
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "*****************************"
echo "Configuring package"
echo "*****************************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    gcrypt_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GCRYPT_DIR}"
    gcrypt_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GCRYPT_DIR}"
else
    gcrypt_cflags="${INSTX_CFLAGS}"
    gcrypt_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${gcrypt_cflags}" \
    CXXFLAGS="${gcrypt_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-shared \
    --with-libgpg-error-prefix="${INSTX_PREFIX}" \
    --with-pth-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]
then
    echo ""
    echo "*****************************"
    echo "Failed to configure libgcrypt"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "*****************************"
echo "Building package"
echo "*****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to build libgcrypt"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*****************************"
echo "Testing package"
echo "*****************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}" 2>&1 | tee "${GCRYPT_LOG}"
then
    echo ""
    echo "*****************************"
    echo "Failed to test libgcrypt"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*****************************"
echo "Installing package"
echo "*****************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GCRYPT_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GCRYPT_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

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
