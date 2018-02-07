#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Libtool from sources.

LIBTOOL_TAR=libtool-2.4.6.tar.gz
LIBTOOL_DIR=libtool-2.4.6

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

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** libtool and libltdl **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libtool/$LIBTOOL_TAR" -O "$LIBTOOL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download libtool and libltdl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$LIBTOOL_DIR" &>/dev/null
gzip -d < "$LIBTOOL_TAR" | tar xf -
cd "$LIBTOOL_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --enable-shared --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure libtool and libltdl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libtool and libltdl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# https://lists.gnu.org/archive/html/bug-libtool/2017-10/msg00009.html
# MAKE_FLAGS=("check" "V=1")
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test libtool and libltdl"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$LIBTOOL_TAR" "$LIBTOOL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libtool.sh 2>&1 | tee build-libtool.log
    if [[ -e build-libtool.log ]]; then
        rm -f build-libtool.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
