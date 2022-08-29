#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds LZ4 from sources.

LZ4_VER=1.9.3
LZ4_TAR=v${LZ4_VER}.tar.gz
LZ4_DIR=lz4-${LZ4_VER}
PKG_NAME=lz4

###############################################################################

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

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================== LZ4 ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "LZ4 ${LZ4_VER}..."

# https://github.com/lz4/lz4/archive/refs/tags/v1.9.3.tar.gz
if ! "${WGET}" -q -O "$LZ4_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/lz4/lz4/archive/refs/tags/$LZ4_TAR"
then
    echo "Failed to download LZ4"
    exit 1
fi

rm -rf "$LZ4_DIR" &>/dev/null
gzip -d < "$LZ4_TAR" | tar xf -
cd "$LZ4_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/lz4.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/lz4.patch
fi

# Failed 'make check'
cp -p lib/xxhash.h programs/xxhash.h
cp -p lib/lz4hc.h programs/lz4hc.h
cp -p lib/lz4.h programs/lz4.h
cp -p lib/lz4frame.h programs/lz4frame.h

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    lz4_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CRYPTOPP_DIR}"
    lz4_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CRYPTOPP_DIR}"
else
    lz4_cflags="${INSTX_CFLAGS}"
    lz4_cxxflags="${INSTX_CXXFLAGS}"
fi

echo ""
echo "************************"
echo "Building package"
echo "************************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "$INSTX_CPPFLAGS" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "$INSTX_ASFLAGS" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${lz4_cflags}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${lz4_cxxflags}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("allmost" "-j" "${INSTX_JOBS}" "V=1")
MAKE_FLAGS+=(CPPFLAGS="-I. ${CPPFLAGS}")
MAKE_FLAGS+=(ASFLAGS="${ASFLAGS}")
MAKE_FLAGS+=(CFLAGS="${CFLAGS}")
MAKE_FLAGS+=(CXXFLAGS="${CXXFLAGS}")
MAKE_FLAGS+=(LDFLAGS="${LDFLAGS}")
MAKE_FLAGS+=(LIBS="${LIBS}")
MAKE_FLAGS+=(LDLIBS="${LIBS}")

if ! CPPFLAGS="${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to build LZ4"
    echo "**********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to test LZ4"
    echo "**********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" PREFIX="${INSTX_PREFIX}")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
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
    ARTIFACTS=("$LZ4_TAR" "$LZ4_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
