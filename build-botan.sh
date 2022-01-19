#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Botan library from sources.

# https://botan.randombit.net/releases/Botan-2.17.3.tar.xz

BOTAN_VER=2.19.0
BOTAN_XZ=Botan-${BOTAN_VER}.tar.xz
BOTAN_TAR=Botan-${BOTAN_VER}.tar
BOTAN_DIR=Botan-${BOTAN_VER}
PKG_NAME=botan

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

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
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
echo "================ Botan ================="
echo "========================================"

echo ""
echo "*************************"
echo "Downloading package"
echo "*************************"

echo ""
echo "Botan ${BOTAN_VER}..."

if ! "$WGET" -q -O "$BOTAN_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://botan.randombit.net/releases/$BOTAN_XZ"
then
    echo "Failed to download Botan"
    exit 1
fi

rm -rf "$BOTAN_TAR" "$BOTAN_DIR" &>/dev/null
unxz "$BOTAN_XZ" && tar -xf "$BOTAN_TAR"
cd "$BOTAN_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/botan.patch ]]; then
    echo ""
    echo "***************************"
    echo "Patching package"
    echo "***************************"

    patch -u -p0 < ../patch/botan.patch
fi

echo ""
echo "*************************"
echo "Configuring package"
echo "*************************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--libdir=${INSTX_LIBDIR}")
CONFIG_OPTS+=("--cc-bin=${CXX}")
CONFIG_OPTS+=("--cxxflags=${INSTX_CPPFLAGS} ${INSTX_CXXFLAGS}")
CONFIG_OPTS+=("--ldflags=${INSTX_LDFLAGS}")
CONFIG_OPTS+=("--system-cert-bundle=${INSTX_CACERT_FILE}")
CONFIG_OPTS+=("--with-bzip2")
CONFIG_OPTS+=("--with-zlib")

if ! ./configure.py "${CONFIG_OPTS[@]}";
then
    echo ""
    echo "*************************"
    echo "Failed to configure Botan"
    echo "*************************"
    exit 1
fi

echo ""
echo "*************************"
echo "Building package"
echo "*************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*************************"
    echo "Failed to build Botan"
    echo "*************************"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "*************************"
echo "Testing package"
echo "*************************"

MAKE_FLAGS=("check" "-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*************************"
    echo "Failed to test Botan"
    echo "*************************"
    exit 1
fi

echo ""
echo "*************************"
echo "Installing package"
echo "*************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "${CURR_DIR}" || exit 1

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
    ARTIFACTS=("$BOTAN_XZ" "$BOTAN_TAR" "$BOTAN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
