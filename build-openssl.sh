#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

# OpenSSH and a few other key programs can only use OpenSSL 1.0.2 at the moment
OPENSSL_TAR=openssl-1.0.2n.tar.gz
OPENSSL_DIR=openssl-1.0.2n

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
    echo "ClamAV requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/identrust-root-x3.pem" ]]; then
    echo "ClamAV requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# May be skipped if Perl is too old
SKIP_OPENSSL_TESTS=0

# Wget self tests
if ! perl -MTest::More -e1 2>/dev/null
then
    echo "OpenSSL requires Perl's Test::More. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Test-More."
    SKIP_OPENSSL_TESTS=1
fi

# Wget self tests
if ! perl -MText::Template -e1 2>/dev/null
then
    echo "OpenSSL requires Perl's Text::Template. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Text-Template."
    SKIP_OPENSSL_TESTS=1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
source ./build-environ.sh

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

IS_DARWIN=$(uname -s 2>&1 | grep -i -c darwin)
IS_GMAKE=$($MAKE -v 2>&1 | grep -i -c 'gnu make')

# OpenSSL and enable-ec_nistp_64_gcc_128 option
IS_X86_64=$(uname -m 2>&1 | grep -E -i -c "(amd64|x86_64)")
if [[ "$BUILD_BITS" -eq "32" ]]; then IS_X86_64=0; fi

# Fix LD_LIBRARY_PATH on Darwin for self-tests
IS_DARWIN=$(uname -s 2>&1 | grep -i -c darwin)

###############################################################################

echo
echo "********** OpenSSL **********"
echo

# wget on Ubuntu 16 cannot validate against Let's Encrypt certificate
wget --ca-certificate="$IDENTRUST_ROOT" "https://www.openssl.org/source/$OPENSSL_TAR" -O "$OPENSSL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
gzip -d < "$OPENSSL_TAR" | tar xf -
cd "$OPENSSL_DIR"

CONFIG_PROG="./config"
CONFIG_FLAGS=("no-ssl2" "no-ssl3" "no-comp" "shared" "-DNDEBUG")

if [[ "$IS_X86_64" -eq "1" ]]; then
    CONFIG_FLAGS+=("enable-ec_nistp_64_gcc_128")
fi

if [[ ! -z "$SH_RPATH" ]]; then
    CONFIG_FLAGS+=("$SH_RPATH")
fi
if [[ ! -z "$SH_DTAGS" ]]; then
    CONFIG_FLAGS+=("$SH_DTAGS")
fi

CONFIG_LIBDIR=$(basename "$INSTX_LIBDIR")
CONFIG_FLAGS+=("--prefix=$INSTX_PREFIX" "--libdir=$CONFIG_LIBDIR")

echo "Configuring OpenSSL with ${CONFIG_FLAGS[*]}"
echo "BUILD_BITS: $BUILD_BITS"

KERNEL_BITS="$BUILD_BITS" "$CONFIG_PROG" "${CONFIG_FLAGS[@]}"

if [[ "$IS_DARWIN" -ne "0" ]]; then
    for mfile in $(find "$PWD" -name 'Makefile'); do
        sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "depend")
if ! "$MAKE" "MAKE_JOBS=$MAKE_JOBS" "${MAKE_FLAGS[@]}"
then
    echo "Failed to update OpenSSL dependencies"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Self tests are still unreliable, https://github.com/openssl/openssl/issues/4963
# TODO: tie self-tests to SKIP_OPENSSL_TESTS
# MAKE_FLAGS=("-j" "$MAKE_JOBS" test)
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test OpenSSL"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

MAKE_FLAGS=(install_sw)
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S rm -rf /usr/local/usr/
else
    "$MAKE" "${MAKE_FLAGS[@]}"
    rm -rf /usr/local/usr/
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

    ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssl.sh 2>&1 | tee build-openssl.log
    if [[ -e build-openssl.log ]]; then
        rm -f build-openssl.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
