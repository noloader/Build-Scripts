#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds b2sum from sources.

# https://github.com/BLAKE2/BLAKE2/archive/20160619.tar.gz
B2SUM_TAR=20160619.tar.gz
B2SUM_DIR=BLAKE2-20160619

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "b2sum requires several CA roots. Please run build-cacert.sh."
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
echo "********** b2sum **********"
echo

# Redirect to Sourceforge.
wget --no-check-certificate "https://github.com/BLAKE2/BLAKE2/archive/$B2SUM_TAR" -O "$B2SUM_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download b2sum"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$B2SUM_DIR" &>/dev/null
gzip -d < "$B2SUM_TAR" | tar xf -
cd "$B2SUM_DIR/b2sum"

if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    sed "s|-march=native ||g" makefile > makefile.fixed
	mv makefile.fixed makefile
fi

sed "s|-Werror=declaration-after-statement||g" makefile > makefile.fixed
mv makefile.fixed makefile

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build b2sum"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Ugh, no 'check' or 'test' targets
#MAKE_FLAGS=("check")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test b2sum"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "PREFIX=$INSTALL_PREFIX" "$MAKE" "${MAKE_FLAGS[@]}"
else
    "PREFIX=$INSTALL_PREFIX" "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$B2SUM_TAR" "$B2SUM_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-zlib.sh 2>&1 | tee build-zlib.log
    if [[ -e build-zlib.log ]]; then
        rm -f build-zlib.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
