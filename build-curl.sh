#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

CURL_TAR=curl-7.56.1.tar.gz
CURL_DIR=curl-7.56.1

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

# Autotools on Solaris has an implied requirement for GNU gear. Things fall apart without it.
# Also see https://blogs.oracle.com/partnertech/entry/preparing_for_the_upcoming_removal.
if [[ -d "/usr/gnu/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/gnu/bin"*) ]]; then
        echo
        echo "Adding /usr/gnu/bin to PATH for Solaris"
        PATH="/usr/gnu/bin:$PATH"
    fi
elif [[ -d "/usr/swf/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/sfw/bin"*) ]]; then
        echo
        echo "Adding /usr/sfw/bin to PATH for Solaris"
        PATH="/usr/sfw/bin:$PATH"
    fi
elif [[ -d "/usr/ucb/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/ucb/bin"*) ]]; then
        echo
        echo "Adding /usr/ucb/bin to PATH for Solaris"
        PATH="/usr/ucb/bin:$PATH"
    fi
fi

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
    echo "cURL requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
CURL_CA_ZOO="$HOME/.cacert/cacert.pem"

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)

# The BSDs and Solaris should have GMake installed if its needed
if [[ $(command -v gmake 2>/dev/null) ]]; then
    MAKE="gmake"
else
    MAKE="make"
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -ne "0" ]]; then
    SH_MARCH="-m64"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
elif [[ "$IS_64BIT" -ne "0" ]]; then
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    else
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    fi
else
    SH_MARCH="-m32"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
fi

if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi

MARCH_ERROR=$($CC $SH_MARCH -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$MARCH_ERROR" -ne "0" ]]; then
    SH_MARCH=
fi

SH_PIC="-fPIC"
PIC_ERROR=$($CC $SH_PIC -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$PIC_ERROR" -ne "0" ]]; then
    SH_PIC=
fi

# For the benefit of OpenSSL. Make it run fast.
SH_NATIVE="-march=native"
NATIVE_ERROR=$($CC $SH_NATIVE -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    SH_NATIVE=
fi

GNU_LD=$(ld -v 2>&1 | grep -i -c 'GNU ld')
if [[ "$GNU_LD" -ne "0" ]]; then
    SH_ERROR=$(echo 'int main() {}' | $CC -Wl,--enable-new-dtags -x c -o /dev/null - 2>&1 | grep -i -c -E 'fatal|error|not found')
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_DTAGS="-Wl,--enable-new-dtags"
    fi
fi

# cURL CA cert path. Should be the hashes.
if [[ -d "/etc/ssl/certs/" ]]; then
    SH_CACERT_PATH="/etc/ssl/certs/"
elif [[ -d "/etc/openssl/certs" ]]; then
    SH_CACERT_PATH="/etc/openssl/certs"
fi

# cURL CA cert file. Should be the PEM concatenation.
if [[ -f "/etc/ssl/certs/ca-bundle.crt" ]]; then
    SH_CACERT_FILE="/etc/ssl/certs/ca-bundle.crt"
elif [[ -f "/etc/ssl/certs/ca-certificates.crt" ]]; then
    SH_CACERT_FILE="/etc/ssl/certs/ca-certificates.crt"
elif [[ -f "/etc/openssl/certs/cacert.pem" ]]; then
    SH_CACERT_FILE="/etc/openssl/certs/cacert.pem"
fi

###############################################################################

OPT_PKGCONFIG=("$INSTALL_LIBDIR/pkgconfig")
OPT_CPPFLAGS=("-I$INSTALL_PREFIX/include" "-DNDEBUG")
OPT_CFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_CXXFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
OPT_LIBS=("-ldl" "-lpthread")

if [[ ! -z "$SH_DTAGS" ]]; then
    OPT_LDFLAGS+=("$SH_DTAGS")
fi

echo ""
echo "Common flags and options:"
echo "  PKGCONFIG: ${OPT_PKGCONFIG[*]}"
echo "   CPPFLAGS: ${OPT_CPPFLAGS[*]}"
echo "     CFLAGS: ${OPT_CFLAGS[*]}"
echo "   CXXFLAGS: ${OPT_CXXFLAGS[*]}"
echo "    LDFLAGS: ${OPT_LDFLAGS[*]}"
echo "     LDLIBS: ${OPT_LIBS[*]}"

###############################################################################

# If IS_EXPORTED=1, then it was set in the parent shell
IS_EXPORTED=$(export | grep -c SUDO_PASSWORD)
if [[ "$IS_EXPORTED" -eq "0" ]]; then

  echo
  echo "If you enter a sudo password, then it will be used for installation."
  echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
  echo "To avoid sudo and the password, just press ENTER and they won't be used."
  read -r -s -p "Please enter password for sudo: " SUDO_PASSWORD
  echo

  # If IS_EXPORTED=2, then we unset it after we are done
  export SUDO_PASSWORD
  IS_EXPORTED=2
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-idn.sh
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre.sh
then
    echo "Failed to build PCRE and PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** cURL **********"
echo

wget --ca-certificate="$CURL_CA_ZOO" "https://curl.haxx.se/download/$CURL_TAR" -O "$CURL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$CURL_DIR" &>/dev/null
gzip -d < "$CURL_TAR" | tar xf -
cd "$CURL_DIR"

CURL_CONFIG_OPTIONS=("--enable-shared" "--enable-static" "--enable-optimize" "--enable-symbol-hiding"
                     "--enable-http" "--enable-ftp" "--enable-file" "--enable-ldap" "--enable-ldaps"
                     "--enable-rtsp" "--enable-proxy" "--enable-dict" "--enable-telnet" "--enable-tftp"
                     "--enable-pop3" "--enable-imap" "--enable-smb" "--enable-smtp" "--enable-gopher"
                     "--enable-cookies" "--enable-ipv6"
                     "--with-zlib=$INSTALL_PREFIX" "--with-ssl=$INSTALL_PREFIX" "--without-gnutls"
                     "--without-polarssl" "--without-mbedtls" "--without-cyassl" "--without-nss"
                     "--without-libssh2" "--with-libidn2=$INSTALL_PREFIX" "--with-nghttp2")

if [[ ! -z "$SH_CACERT_PATH" ]]; then
    CURL_CONFIG_OPTIONS+=("--with-ca-path=$SH_CACERT_PATH")
else
    CURL_CONFIG_OPTIONS+=("--without-ca-path")
fi

if [[ ! -z "$SH_CACERT_FILE" ]]; then
    CURL_CONFIG_OPTIONS+=("--with-ca-bundle=$SH_CACERT_FILE")
else
    CURL_CONFIG_OPTIONS+=("--without-ca-bundle")
fi

    PKG_CONFIG_PATH="${OPT_PKGCONFIG[*]}" \
    CPPFLAGS="${OPT_CPPFLAGS[*]}" \
    CFLAGS="${OPT_CFLAGS[*]}" \
    CXXFLAGS="${OPT_CXXFLAGS[*]}" \
    LDFLAGS="${OPT_LDFLAGS[*]}" \
    LIBS="-lidn2 -lssl -lcrypto -lz ${OPT_LIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    "${CURL_CONFIG_OPTIONS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# MAKE_FLAGS=("check")
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test cURL"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

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

    ARTIFACTS=("$CURL_TAR" "$CURL_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-curl.sh 2>&1 | tee build-curl.log
    if [[ -e build-curl.log ]]; then
        rm -f build-curl.log
    fi
fi

# If IS_EXPORTED=2, then we set it
if [[ "$IS_EXPORTED" -eq "2" ]]; then
    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
