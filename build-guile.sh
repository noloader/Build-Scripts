#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Guile from sources. Guile has a lot of issues
# and I am not sure all of them can be worked around.
#
# Requires libtool-ltdl-devel on Fedora.

GUILE_VER=2.2.7
GUILE_TAR=guile-${GUILE_VER}.tar.gz
GUILE_DIR=guile-${GUILE_VER}
PKG_NAME=guile

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

# Boehm garbage collector. Look in /usr/lib and /usr/lib64
if [[ "$IS_DEBIAN" -ne 0 ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "Guile requires Boehm garbage collector. Please install libgc-dev."
        exit 1
    fi
elif [[ "$IS_FEDORA" -ne 0 ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "Guile requires Boehm garbage collector. Please install gc-devel."
        exit 1
    fi
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
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

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

# Solaris is missing the Boehm GC. We have to build it. Ugh...
if [[ "$IS_SOLARIS" -eq 1 ]]; then
    if ! ./build-boehm-gc.sh
    then
        echo "Failed to build Boehm GC"
        exit 1
    fi
fi

###############################################################################

if ! ./build-libffi.sh
then
    echo "Failed to build libffi"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Guile ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Guile ${GUILE_VER}..."

if ! "$WGET" -q -O "$GUILE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/guile/$GUILE_TAR"
then
    echo "Failed to download Guile"
    exit 1
fi

rm -rf "$GUILE_DIR" &>/dev/null
gzip -d < "$GUILE_TAR" | tar xf -
cd "$GUILE_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--with-pic")
CONFIG_OPTS+=("--disable-deprecated")
CONFIG_OPTS+=("--with-libgmp-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libunistring-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libiconv-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libltdl-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libintl-prefix=${INSTX_PREFIX}")

# --with-bdw-gc="${INSTX_PKGCONFIG}/"
# --disable-posix --disable-networking

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
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Guile"
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
    echo "Failed to build Guile"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# https://lists.gnu.org/archive/html/guile-devel/2017-10/msg00009.html
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Guile"
    # exit 1
fi

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

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GUILE_TAR" "$GUILE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
