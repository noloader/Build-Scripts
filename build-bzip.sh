#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

BZIP2_TAR=bzip2-1.0.6.tar.gz
BZIP2_DIR=bzip2-1.0.6

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

IS_DARWIN=$(uname -s | grep -i -c darwin)
if [[ ("$IS_DARWIN" -eq "0") ]] && [[ -z $(command -v libtoolize 2>/dev/null) ]]; then
    echo "Some packages require libtool. Please install libtool or libtool-bin."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "zLib requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
if [[ -z "$BUILD_OPTS" ]]; then
    source ./build-environ.sh
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** Bzip **********"
echo

wget "http://www.bzip.org/1.0.6/$BZIP2_TAR" -O "$BZIP2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR"

# Fix Bzip install paths
cp Makefile Makefile.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Fix Bzip cpu architecture
cp Makefile Makefile.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
cp Makefile Makefile.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Fix Bzip missing PIC
cp Makefile Makefile.orig
sed "s|CFLAGS=|CFLAGS=$SH_PIC |g" Makefile.orig > Makefile
cp Makefile Makefile.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_PIC |g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CFLAGS=|CFLAGS=$SH_PIC |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_PIC |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Add RPATH
cp Makefile Makefile.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install "PREFIX=$INSTALL_PREFIX" "LIBDIR=$INSTALL_LIBDIR")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssl.sh 2>&1 | tee build-openssl.log
    if [[ -e build-openssl.log ]]; then
        rm -f build-openssl.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
