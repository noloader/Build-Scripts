#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Zstd from sources.

# v1.5.1 suffers from loss of NX-stacks due to huf_decompress_amd64.S
# $ find . -name '*.S'
# lib/decompress/huf_decompress_amd64.S
# $ grep -IR huf_decompress_amd64.S
# build/meson/lib/meson.build:  join_paths(zstd_rootdir, 'lib/decompress/huf_decompress_amd64.S'),

ZSTD_VER=1.5.1
ZSTD_GH_VER=v1.5.1
ZSTD_TAR="zstd-${ZSTD_VER}.tar.gz"
ZSTD_DIR="zstd-${ZSTD_VER}"
PKG_NAME=zstd

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Zstd ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Zstd ${ZSTD_VER}..."

if ! "${WGET}" -q -O "$ZSTD_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/facebook/zstd/releases/download/$ZSTD_GH_VER/$ZSTD_TAR"
then
    echo "Failed to download Zstd"
    exit 1
fi

rm -rf "$ZSTD_DIR" &>/dev/null
gzip -d < "$ZSTD_TAR" | tar xf -
cd "$ZSTD_DIR" || exit 1

# cp -p programs/Makefile programs/Makefile.orig
# cp -p tests/Makefile tests/Makefile.orig
# cp -p tests/fuzz/Makefile tests/fuzz/Makefile.orig
# cp -p lib/Makefile lib/Makefile.orig
# cp -p lib/libzstd.mk lib/libzstd.mk.orig
# cp -p contrib/linux-kernel/test/Makefile contrib/linux-kernel/test/Makefile.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/zstd.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/zstd.patch
fi

# echo "" > ../patch/zstd.patch
# diff -u programs/Makefile.orig programs/Makefile >> ../patch/zstd.patch
# diff -u tests/Makefile.orig tests/Makefile >> ../patch/zstd.patch
# diff -u tests/fuzz/Makefile.orig tests/fuzz/Makefile >> ../patch/zstd.patch
# diff -u lib/Makefile.orig lib/Makefile >> ../patch/zstd.patch
# diff -u lib/libzstd.mk.orig lib/libzstd.mk >> ../patch/zstd.patch
# diff -u contrib/linux-kernel/test/Makefile.orig contrib/linux-kernel/test/Makefile >> ../patch/zstd.patch

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    zstd_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${ZSTD_DIR}"
    zstd_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${ZSTD_DIR}"
else
    zstd_cflags="${INSTX_CFLAGS}"
    zstd_cxxflags="${INSTX_CXXFLAGS}"
fi

# Since we call the makefile directly, we need to escape dollar signs.
export CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
export ASFLAGS=$(echo "${INSTX_ASFLAGS}" | sed 's/\$/\$\$/g')
export CFLAGS=$(echo "${zstd_cflags}" | sed 's/\$/\$\$/g')
export CXXFLAGS=$(echo "${zstd_cxxflags}" | sed 's/\$/\$\$/g')
export LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
export LIBS="${INSTX_LDLIBS}"

export PREFIX="${INSTX_PREFIX}"
export LIBDIR="${INSTX_LIBDIR}"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to build Zstd"
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
    echo "Failed to test Zstd"
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

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${ZSTD_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${ZSTD_DIR}"
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
    ARTIFACTS=("$ZSTD_TAR" "$ZSTD_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
