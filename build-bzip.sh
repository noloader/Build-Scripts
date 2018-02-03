#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

BZIP2_TAR=bzip2-1.0.6.tar.gz
BZIP2_DIR=bzip2-1.0.6
PKG_NAME=bzip2

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
source ./build-environ.sh

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

# Squash a warning
sed -e '558i \
(void)nread;' bzip2.c > bzip2.c.fixed
mv bzip2.c.fixed bzip2.c

# Fix format specifier
if [[ "$IS_64BIT" -ne "0" ]]; then
    for cfile in $(find "$PWD" -name '*.c'); do
        sed -e "s|%Lu|%llu|g" "$cfile" > "$cfile.fixed"
        mv "$cfile.fixed" "$cfile"
    done
fi

# Fix Bzip install paths
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile-libbz2_so > Makefile-libbz2_so.fixed
mv Makefile-libbz2_so.fixed Makefile-libbz2_so

# Hack to get around the array and regular expression in the sed
TEMP_CPPFLAGS="${BUILD_CPPFLAGS[@]}"
TEMP_CFLAGS="${BUILD_CFLAGS[@]}"
TEMP_CXXFLAGS="${BUILD_CXXFLAGS[@]}"

# Fix flags
sed -e "s|^CFLAGS=*|CFLAGS=$TEMP_CPPFLAGS $TEMP_CFLAGS |g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|^CXXFLAGS=*|CFLAGS=$TEMP_CPPFLAGS $TEMP_CXXFLAGS |g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|^CFLAGS=*|CFLAGS=$TEMP_CPPFLAGS $TEMP_CFLAGS |g" Makefile-libbz2_so > Makefile-libbz2_so.fixed
mv Makefile-libbz2_so.fixed Makefile-libbz2_so
sed -e "s|^CXXFLAGS=*|CFLAGS=$TEMP_CPPFLAGS $TEMP_CXXFLAGS |g" Makefile-libbz2_so > Makefile-libbz2_so.fixed
mv Makefile-libbz2_so.fixed Makefile-libbz2_so

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install "PREFIX=$INSTX_PREFIX" "LIBDIR=$INSTX_LIBDIR")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-bzip.sh 2>&1 | tee build-bzip.log
    if [[ -e build-bzip.log ]]; then
        rm -f build-bzip.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
