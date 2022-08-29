#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds UT Hash from sources.

UTHASH_VER="2.1.0"
UTHASH_TAR="v$UTHASH_VER.tar.gz"
UTHASH_DIR="uthash-$UTHASH_VER"
PKG_NAME=uthash

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
echo "================ UT Hash ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "${WGET}" -q -O "$UTHASH_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/troydhanson/uthash/archive/$UTHASH_TAR"
then
    echo "Failed to download UT Hash"
    exit 1
fi

rm -rf "$UTHASH_DIR" &>/dev/null
gzip -d < "$UTHASH_TAR" | tar xf -
cd "$UTHASH_DIR"

if [[ -e ../patch/uthash.patch ]]; then
    patch -u -p0 < ../patch/uthash.patch
    echo ""
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Testing package"
echo "**********************"

# No Autotools or makefile in src/
cd tests

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
MAKE_FLAGS+=("PKG_CONFIG_PATH=${INSTX_PKGCONFIG}")
MAKE_FLAGS+=("CPPFLAGS=${INSTX_CPPFLAGS}")
MAKE_FLAGS+=("ASFLAGS=${INSTX_ASFLAGS}")
MAKE_FLAGS+=("CFLAGS=${INSTX_CFLAGS}")
MAKE_FLAGS+=("CXXFLAGS=${INSTX_CXXFLAGS}")
MAKE_FLAGS+=("LDFLAGS=${INSTX_LDFLAGS}")
MAKE_FLAGS+=("LIBS=${INSTX_LDLIBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test UT Hash"
   exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Installing package"
echo "**********************"

cd ../src/

if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp *.h "${INSTX_PREFIX}/include/"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    cp *.h "${INSTX_PREFIX}/include/"
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
    ARTIFACTS=("$UTHASH_TAR" "$UTHASH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
