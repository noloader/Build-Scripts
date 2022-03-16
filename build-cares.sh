#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds c-ares from sources. c-ares causes
# a fair amount of trouble. It is on a backslide since
# Daniel turned over reigns to other developers.

CARES_VER=1.18.1
CARES_TAR=c-ares-${CARES_VER}.tar.gz
CARES_DIR=c-ares-${CARES_VER}
PKG_NAME=c-ares

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
echo "================ C-ares ================"
echo "========================================"

echo ""
echo "**************************"
echo "Downloading package"
echo "**************************"

echo ""
echo "C-ares ${CARES_VER}..."

if ! "$WGET" -q -O "$CARES_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://c-ares.haxx.se/download/$CARES_TAR"
then
    echo "Failed to download c-ares"
    exit 1
fi

rm -rf "$CARES_DIR" &>/dev/null
gzip -d < "$CARES_TAR" | tar xf -
cd "$CARES_DIR" || exit 1

if [[ -e ../patch/cares.patch ]]; then
    echo ""
    echo "**************************"
    echo "Patching package"
    echo "**************************"

    patch -u -p0 < ../patch/cares.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**************************"
echo "Configuring package"
echo "**************************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    cares_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CARES_DIR}"
    cares_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CARES_DIR}"
else
    cares_cflags="${INSTX_CFLAGS}"
    cares_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${cares_cflags}" \
    CXXFLAGS="${cares_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static \
    --enable-shared \
    --enable-tests

if [[ "$?" -ne 0 ]]
then
    echo ""
    echo "**************************"
    echo "Failed to configure c-ares"
    echo "**************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**************************"
echo "Building package"
echo "**************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to build c-ares"
    echo "**************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**************************"
echo "Testing package"
echo "**************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to test c-ares"
    echo "**************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    # exit 1

    echo ""
    echo "**************************"
    echo "Installing anyways..."
    echo "**************************"
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**************************"
echo "Installing package"
echo "**************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${CARES_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${CARES_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$CARES_TAR" "$CARES_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
