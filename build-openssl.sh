#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

# OpenSSH and a few other key programs can only use OpenSSL 1.0.2 at the moment
OPENSSL_TAR=openssl-1.0.2l.tar.gz
OPENSSL_DIR=openssl-1.0.2l

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

IS_DARWIN=$(uname -s 2>&1 | grep -i -c darwin)
IS_GMAKE=$($MAKE -v 2>&1 | grep -i -c 'gnu make')

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

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_64BIT" -ne "0" ]]; then
    SH_KBITS=64
else
    SH_KBITS=32
fi

# OpenSSL and enable-ec_nistp_64_gcc_128 option
IS_X86_64=$(uname -m 2>&1 | grep -E -i -c "(amd64|x86_64)")
if [[ "$SH_KBITS" -eq "32" ]]; then IS_X86_64=0; fi

CONFIG_PROG="./config"
CONFIG_FLAGS=("no-ssl2" "no-ssl3" "no-comp" "shared" "-DNDEBUG")

if [[ ! -z "$SH_RPATH" ]]; then
    CONFIG_FLAGS+=("$SH_RPATH")
fi
if [[ ! -z "$SH_DTAGS" ]]; then
    CONFIG_FLAGS+=("$SH_DTAGS")
fi
if [[ "$IS_X86_64" -eq "1" ]]; then
    CONFIG_FLAGS+=("enable-ec_nistp_64_gcc_128")
fi

CONFIG_FLAGS+=("--prefix=$INSTALL_PREFIX" "--libdir=$(basename "$INSTALL_LIBDIR")")

echo "Configuring OpenSSL with ${CONFIG_FLAGS[*]}"
echo ""

KERNEL_BITS="$SH_KBITS" "$CONFIG_PROG" "${CONFIG_FLAGS[@]}"

# OpenSSL configuration is so broken. The dev team just makes the
#   shit up as they go rather than following conventions.
for mfile in $(find "$PWD" -name 'Makefile'); do
    sed -e 's|$(INSTALL_PREFIX)|$(DESTDIR)|g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
    if [[ "$IS_GMAKE" -ne "0" ]]; then
        sed -e 's|$(MAKE)|$(MAKE) -j $(MAKE_JOBS)|g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    fi
done

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "depend")
if ! "$MAKE" "MAKE_JOBS=$MAKE_JOBS" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL dependencies"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install_sw)
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S rm -rf /usr/local/usr/
else
    "$MAKE" "${MAKE_FLAGS[@]}"
    rm -rf /usr/local/usr/
fi

cd "$CURR_DIR"

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
