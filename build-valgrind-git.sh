#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Valgrind from sources.

VALGRIND_DIR=valgrind-master
PKG_NAME=valgrind

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
echo "=============== Valgrind ==============="
echo "========================================"

rm -rf "$VALGRIND_DIR" 2>/dev/null

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

if ! git clone --depth=3 git://sourceware.org/git/valgrind.git "$VALGRIND_DIR";
then
    echo "Failed to checkout Valgrind"
    exit 1
fi

cd "$VALGRIND_DIR"
git checkout master &>/dev/null

if ! ./autogen.sh
then
    echo "Failed to generate Valgrind build files"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="-g2 -O3" \
    ASFLAGS="" \
    CFLAGS="-g2 -O3" \
    CXXFLAGS="-g2 -O3" \
    LDFLAGS="" \
    LIBS="" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Valgrind"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Valgrind"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# Man, Valgirnd is awful when it comes to trying to build self tests.
# MAKE_FLAGS=("check" "-k" "V=1")
# if ! "${MAKE}" "${MAKE_FLAGS[@]}"
# then
#    echo "Failed to test Valgrind"
#    exit 1
# fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
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
    ARTIFACTS=("$VALGRIND_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
