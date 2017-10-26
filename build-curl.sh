#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

CURL_TAR=curl-7.56.1.tar.gz
CURL_DIR=curl-7.56.1

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
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

# Get environment if needed. We can't export it because it includes arrays.
if [[ -z "$BUILD_OPTS" ]]; then
    source ./build-environ.sh
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
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

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

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

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="-lidn2 -lssl -lcrypto -lz ${BUILD_LIBS[*]}" \
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

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
