#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Nettle from sources.

NETTLE_TAR=nettle-3.4.tar.gz
NETTLE_DIR=nettle-3.4
PKG_NAME=nettle

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
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Nettle **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/nettle/$NETTLE_TAR" -O "$NETTLE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NETTLE_DIR" &>/dev/null
gzip -d < "$NETTLE_TAR" | tar xf -
cd "$NETTLE_DIR"

# This works for all versions of Nettle on all Apple platforms
if [[ "$IS_DARWIN" -ne "0" ]]; then
    sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' examples/Makefile.in > examples/Makefile.in.fixed
    mv examples/Makefile.in.fixed examples/Makefile.in
    sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' testsuite/Makefile.in > testsuite/Makefile.in.fixed
    mv testsuite/Makefile.in.fixed testsuite/Makefile.in
fi

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

CONFIG_OPTS=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")

if [[ "$IS_IA32" -ne "0" ]]; then
    CONFIG_OPTS+=("--enable-fat")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[@]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[@]}" \
    CFLAGS="${BUILD_CFLAGS[@]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[@]}" \
    LDFLAGS="${BUILD_LDFLAGS[@]}" \
    LIBS="${BUILD_LIBS[@]}" \
./configure ${CONFIG_OPTS[*]}

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

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

    ARTIFACTS=("$NETTLE_TAR" "$NETTLE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-nettle.sh 2>&1 | tee build-nettle.log
    if [[ -e build-nettle.log ]]; then
        rm -f build-nettle.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
