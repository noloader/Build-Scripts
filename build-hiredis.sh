#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Hiredis from sources.

HIREDIS_VER=1.0.0
HIREDIS_TAR=v${HIREDIS_VER}.tar.gz
HIREDIS_DIR=hiredis-${HIREDIS_VER}
PKG_NAME=hiredis

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

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== Hiredis ================"
echo "========================================"

echo ""
echo "***********************"
echo "Downloading package"
echo "***********************"

echo ""
echo "Hiredis ${HIREDIS_VER}..."

if ! "$WGET" -q -O "$HIREDIS_TAR" --ca-certificate="$GITHUB_CA_ZOO" \
     "https://github.com/redis/hiredis/archive/$HIREDIS_TAR"
then
    echo "Failed to download Hiredis"
    exit 1
fi

rm -rf "$HIREDIS_DIR" &>/dev/null
gzip -d < "$HIREDIS_TAR" | tar xf -
cd "$HIREDIS_DIR"

if [[ -e ../patch/hiredis.patch ]]; then
    echo ""
    echo "***********************"
    echo "Patching package"
    echo "***********************"

    patch -u -p0 < ../patch/hiredis.patch
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

# Awful Solaris 64-bit hack. Use -G for SunC, and -shared for GCC
if [[ "$IS_SOLARIS" -ne 0 && "$IS_SUNC" -eq 0 ]]; then
    sed 's/ -G / -shared /g' Makefile > Makefile.fixed
    mv Makefile.fixed Makefile; chmod +x Makefile
fi

echo ""
echo "***********************"
echo "Building package"
echo "***********************"

# Since we call the makefile directly, we need to escape dollar signs.
PKG_CONFIG_PATH="${INSTX_PKGCONFIG}"
CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "${INSTX_ASFLAGS}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile")
MAKE_FLAGS+=("-j" "${INSTX_JOBS}")
MAKE_FLAGS+=("PREFIX=${INSTX_PREFIX}")
MAKE_FLAGS+=("LIBRARY_PATH=${INSTX_LIBDIR}")
MAKE_FLAGS+=("PKGCONF_PATH=${INSTX_PKGCONFIG}")

    CPPFLAGS="${CPPFLAGS}" \
    ASFLAGS="${ASFLAGS}" \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    LDLIBS="${LIBS}" \
    LIBS="${LIBS}" \
"${MAKE}" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***********************"
    echo "Failed to build Hiredis"
    echo "***********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Testing package"
echo "***********************"

echo ""
echo "***********************"
echo "Unable to test Hiredis"
echo "***********************"

# Need redis-server
#MAKE_FLAGS=("check" "-k" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Hidredis"
#    exit 1
#fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Installing package"
echo "***********************"

MAKE_FLAGS=("install")
MAKE_FLAGS+=("PREFIX=${INSTX_PREFIX}")
MAKE_FLAGS+=("LIBDIR=${INSTX_LIBDIR}")
MAKE_FLAGS+=("PKGLIBDIR=${INSTX_PKGCONFIG}")

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
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
    ARTIFACTS=("$HIREDIS_TAR" "$HIREDIS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
