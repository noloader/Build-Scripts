#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Guile from sources. Guile has a lot of issues
# and I am not sure all of them can be worked around.
#
# Requires libtool-ltdl-devel on Fedora.

GUILE_TAR=guile-2.2.3.tar.xz
GUILE_DIR=guile-2.2.3
PKG_NAME=guile

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Boehm garbage collector. Look in /usr/lib and /usr/lib64
if [[ "$IS_DEBIAN" -ne "0" ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "GnuTLS requires Boehm garbage collector. Please install libgc-dev."
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
elif [[ "$IS_FEDORA" -ne "0" ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "GnuTLS requires Boehm garbage collector. Please install gc-devel."
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libffi.sh
then
    echo "Failed to build libffi"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Guile **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/guile/$GUILE_TAR" -O "$GUILE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GUILE_DIR" &>/dev/null
tar xJf "$GUILE_TAR"
cd "$GUILE_DIR"

# Rebuild libtool, http://stackoverflow.com/q/35589427/608639
autoconf

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

# --with-bdw-gc="${BUILD_PKGCONFIG[*]}/"
# --disable-posix --disable-networking

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --enable-static --with-pic \
    --disable-deprecated \
    --with-libgmp-prefix="$INSTX_PREFIX" \
    --with-libunistring-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libltdl-prefix="$INSTX_PREFIX" \
    --with-readline-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# https://lists.gnu.org/archive/html/guile-devel/2017-10/msg00009.html
# MAKE_FLAGS=("check" "V=1")
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test Guile"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GUILE_TAR" "$GUILE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-guile.sh 2>&1 | tee build-guile.log
    if [[ -e build-guile.log ]]; then
        rm -f build-guile.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
