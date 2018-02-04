#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Libffi from sources.

LIBFFI_TAR=libffi-3.2.1.tar.gz
LIBFFI_DIR=libffi-3.2.1
PKG_NAME=libffi

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

# If the package is older than 7 days, then rebuild it. This sidesteps the
# problem of continually rebuilding the same package when installing a
# program like Git and SSH. It also avoids version tracking by automatically
# building a package after 7 days (even if it is the same version).
if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then

    then_time=$(date -d 'now - 7 days' +%s)
    file_time=$(date -r "$INSTX_CACHE/$PKG_NAME" +%s)

    if (( file_time <= then_time ));
    then
        echo ""
        echo "$PKG_NAME is older than 7 days. Rebuilding $PKG_NAME."
        rm -f "$INSTX_CACHE/$PKG_NAME" 2>/dev/null
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

echo
echo "********** libffi **********"
echo

# ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz
wget --ca-certificate="$DIGICERT_ROOT" "ftp://sourceware.org/pub/libffi/$LIBFFI_TAR" -O "$LIBFFI_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download libffi"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$LIBFFI_DIR" &>/dev/null
gzip -d < "$LIBFFI_TAR" | tar xf -
cd "$LIBFFI_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure libffi"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libffi"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test libffi"
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
if false; then

    ARTIFACTS=("$LIBFFI_TAR" "$LIBFFI_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libffi.sh 2>&1 | tee build-libffi.log
    if [[ -e build-libffi.log ]]; then
        rm -f build-libffi.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
