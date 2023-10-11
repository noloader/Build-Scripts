#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libxml2 from sources.

# https://download.gnome.org/sources/libxml2/2.10/libxml2-2.10.2.tar.xz

XML2_URL=2.11
XML2_VER=2.11.5
XML2_XZ=libxml2-${XML2_VER}.tar.xz
XML2_TAR=libxml2-${XML2_VER}.tar
XML2_DIR=libxml2-${XML2_VER}
PKG_NAME=libxml2

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

# libxml2 only uses iConvert

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if [[ ! -f "${INSTX_PREFIX}/bin/xz" ]]
then
    if ! ./build-xz.sh
    then
        echo "Failed to build XZ"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================ libxml2 ==============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

echo ""
echo "libxml2 ${XML2_VER}..."

# To view the FTP listing, curl ftp://xmlsoft.org/libxml2/
# Also see https://mail.gnome.org/archives/xml/2022-January/msg00011.html.

if ! "${WGET}" -q -O "${XML2_XZ}" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://download.gnome.org/sources/libxml2/${XML2_URL}/${XML2_XZ}"
then
    echo "Failed to download Grep"
    exit 1
fi

rm -rf "${XML2_TAR}" "${XML2_DIR}" &>/dev/null
unxz "${XML2_XZ}" && tar -xf "${XML2_TAR}"
cd "${XML2_DIR}" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/libxml2.patch ]]; then
    echo ""
    echo "***************************"
    echo "Patching package"
    echo "***************************"
    patch -u -p0 < ../patch/libxml2.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "***************************"
echo "Configuring package"
echo "***************************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    libxml2_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${XML2_DIR}"
    libxml2_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${XML2_DIR}"
else
    libxml2_cflags="${INSTX_CFLAGS}"
    libxml2_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${libxml2_cflags}" \
    CXXFLAGS="${libxml2_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static --enable-shared \
    --with-fexceptions \
    --with-iconv="${INSTX_PREFIX}" \
    --with-zlib="${INSTX_PREFIX}" \
    --without-legacy \
    --without-python

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***************************"
    echo "Failed to configure libxml2"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to build libxml2"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Testing package"
echo "***************************"

# libxml2 appears to hang on old PowerMacs. Be patient.
# https://mail.gnome.org/archives/xml/2021-March/msg00013.html

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to test libxml2"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Installing package"
echo "***************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${XML2_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${XML2_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("${XML2_TAR}" "${XML2_DIR}")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
