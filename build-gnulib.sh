#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Gnulib from sources.

# Gnulib is distributed as source from GitHub. No packages
# are available for download. Also see
# https://www.linux.com/news/using-gnulib-improve-software-portability

# Testing Gnulib is detailed at https://lists.gnu.org/archive/html/bug-gnulib/2017-05/msg00118.html.

GNULIB_VER=unknown
GNULIB_DIR=gnulib
GNULIB_TEST_DIR=gnulib_test
PKG_NAME=gnulib

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
echo "================ Gnulib ================"
echo "========================================"

echo ""
echo "Gnulib ${GNULIB_VER}..."

# Cleanup old artifacts in case of early out
rm -rf "$GNULIB_DIR" "$GNULIB_TEST_DIR" 2>/dev/null

echo ""
echo "*****************************"
echo "Cloning package"
echo "*****************************"

if ! git clone --depth=3 git://git.savannah.gnu.org/gnulib.git "$GNULIB_DIR"
then
    echo ""
    echo "*****************************"
    echo "Failed to clone Gnulib"
    echo "*****************************"
    exit 1
fi

cd "$GNULIB_DIR" || exit 1

echo "Copying Gnulib sources"
if ! ./gnulib-tool --create-testdir --dir=../"$GNULIB_TEST_DIR" --avoid=gettext --single-configure --without-privileged-tests;
then
    echo ""
    echo "*****************************"
    echo "Failed to copy Gnulib sources"
    echo "*****************************"
    exit 1
fi

cd "${CURR_DIR}" || exit 1
cd "$GNULIB_TEST_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
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
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "*****************************"
    echo "Failed to configure Gnulib"
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
    echo "Failed to build Gnulib"
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

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to test Gnulib"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GNULIB_DIR" "$GNULIB_TEST_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
