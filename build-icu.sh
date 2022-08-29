#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ICU from sources.

# Formerly 66_1
ICU_VER=68_1
ICU_DVER=68.1
ICU_TAR="cu4c-${ICU_VER}-src.tgz"
ICU_DIR=icu
PKG_NAME=icu

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
echo "================ libicu ================"
echo "========================================"

echo ""
echo "**************************"
echo "Downloading package"
echo "**************************"

echo ""
echo "libicu ${ICU_DVER}..."

if ! "${WGET}" -q -O "$ICU_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/unicode-org/icu/releases/download/release-${ICU_DVER}/${ICU_TAR}"
then
    echo "Failed to download libicu"
    exit 1
fi

rm -rf "$ICU_DIR" &>/dev/null
gzip -d < "$ICU_TAR" | tar xf -
cd "$ICU_DIR" || exit 1

if [[ -e ../patch/icu.patch ]]; then
    echo ""
    echo "**************************"
    echo "Patching package"
    echo "**************************"

    patch -u -p0 < ../patch/icu.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "**************************"
echo "Configuring package"
echo "**************************"

cd "source" || exit 1

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
    --enable-shared --enable-static \
    --with-library-bits="$INSTX_BITNESS" \
    --with-data-packaging=auto

if [[ "$?" -ne 0 ]]; then
    echo "**************************"
    echo "Failed to configure libicu"
    echo "**************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "**************************"
echo "Building package"
echo "**************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to build libicu"
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

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to test libicu"
    echo "**************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"

    echo "**************************"
    echo "Installing anyways..."
    echo "**************************"
    # exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**************************"
echo "Installing package"
echo "**************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$ICU_TAR" "$ICU_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
