#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Automake from sources. A separate
# script is available for Autotools for brave souls.

AUTOMAKE_VER=1.16.3
AUTOMAKE_TAR="automake-${AUTOMAKE_VER}.tar.gz"
AUTOMAKE_DIR="automake-${AUTOMAKE_VER}"

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
echo "=============== Automake ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Automake ${AUTOMAKE_VER}..."

if ! "$WGET" -q -O "$AUTOMAKE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/automake/$AUTOMAKE_TAR"
then
    echo "Failed to download Automake"
    exit 1
fi

rm -rf "$AUTOMAKE_DIR" &>/dev/null
gzip -d < "$AUTOMAKE_TAR" | tar xf -
cd "$AUTOMAKE_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

sed -e 's|^MAKEINFO =.*|MAKEINFO = true|g' Makefile > Makefile.fixed
mv Makefile.fixed Makefile

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Automake"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Automake"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "$CURR_DIR" || exit 1

# Update program cache
[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$AUTOMAKE_TAR" "$AUTOMAKE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
