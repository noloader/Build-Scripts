#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds dos2unix from sources.

DOS2UNIX_VER=7.4.1
DOS2UNIX_TAR=dos2unix-${DOS2UNIX_VER}.tar.gz
DOS2UNIX_DIR=dos2unix-${DOS2UNIX_VER}

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

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-gettext-final.sh
then
    echo echo "Failed to build GetText final"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== dos2unix ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "dos2unix ${DOS2UNIX_VER}..."

if ! "$WGET" -q -O "$DOS2UNIX_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://waterlan.home.xs4all.nl/dos2unix/$DOS2UNIX_TAR"
then
    echo "Failed to download dos2unix"
    exit 1
fi

rm -rf "$DOS2UNIX_DIR" &>/dev/null
gzip -d < "$DOS2UNIX_TAR" | tar xf -
cd "$DOS2UNIX_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/dos2unix.patch ]]; then
    patch -u -p0 < ../patch/dos2unix.patch
    echo ""
fi

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! CPPFLAGS="${CPPFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="-liconv ${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build dos2unix"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test dos2unix"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "prefix=${INSTX_PREFIX}" "libdir=${INSTX_LIBDIR}")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "$CURR_DIR" || exit 1

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$DOS2UNIX_TAR" "$DOS2UNIX_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0