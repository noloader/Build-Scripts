#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds IDN from sources.

# Use libidn-1.33 for Solaris and OS X... IDN2 causes too
# many problems and too few answers on the mailing list.
IDN_TAR=libidn-1.33.tar.gz
IDN_DIR=libidn-1.33

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
    echo "IDN requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

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
echo "********** IDN **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libidn/$IDN_TAR" -O "$IDN_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$IDN_DIR" &>/dev/null
gzip -d < "$IDN_TAR" | tar xf -
cd "$IDN_DIR"

if [[ "$IS_SOLARIS" -eq "1" ]]; then
  if [[ (-f src/idn2.c) ]]; then
    cp src/idn2.c src/idn2.c.orig
    sed '/^#include "error.h"/d' src/idn2.c.orig > src/idn2.c
    cp src/idn2.c src/idn2.c.orig
    sed '43istatic void error (int status, int errnum, const char *format, ...);' src/idn2.c.orig > src/idn2.c
    rm src/idn2.c.orig

    {
      echo ""
      echo "static void"
      echo "error (int status, int errnum, const char *format, ...)"
      echo "{"
      echo "  va_list args;"
      echo "  va_start(args, format);"
      echo "  vfprintf(stderr, format, args);"
      echo "  va_end(args);"
      echo "  exit(status);"
      echo "}"
      echo ""
    } >> src/idn2.c
  fi
fi

# Darwin is mostly fucked up at the moment. Also see
# http://lists.gnu.org/archive/html/help-libidn/2017-10/msg00002.html
if [[ "$IS_DARWIN" -ne "0" ]]; then
    sed -i "" 's|$AR cru|$AR $ARFLAGS|g' configure
    sed -i "" 's|${AR_FLAGS=cru}|${AR_FLAGS=-static -o }|g' configure
    #sed -i "" 's|$AR cru|$AR $ARFLAGS|g' aclocal.m4
    #sed -i "" 's|$AR cr|$AR $ARFLAGS|g' aclocal.m4
    #sed -i "" 's|$AR cru|$AR $ARFLAGS|g' m4/libtool.m4
    #sed -i "" 's|$AR cr|$AR $ARFLAGS|g' m4/libtool.m4
    #sed -i "" 's|${AR_FLAGS=cru}|${AR_FLAGS=-static -o }|g' m4/libtool.m4

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

    for mfile in $(find "$PWD" -iname 'Makefile'); do
        echo "Fixing makefile $mfile"
        sed -i "" 's|AR = ar|AR = /usr/bin/libtool|g' "$mfile"
        sed -i "" 's|ARFLAGS = cru |ARFLAGS = -static -o |g' "$mfile"
        sed -i "" 's|ARFLAGS = cr |ARFLAGS = -static -o |g' "$mfile"
    done

    #for sfile in $(find "$PWD" -iname '*.sh'); do
    #    echo "Fixing script $sfile"
    #    sed -i "" 's|$AR cru |$AR $ARFLAGS |g' "$sfile"
    #    sed -i "" 's|$AR cr |$AR $ARFLAGS |g' "$sfile"
    #done

else

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$IDN_TAR" "$IDN_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-idn.sh 2>&1 | tee build-idn.log
    if [[ -e build-idn.log ]]; then
        rm -f build-idn.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
