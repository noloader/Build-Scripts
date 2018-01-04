#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

GNUTLS_TAR=gnutls-3.5.16.tar.xz
GNUTLS_DIR=gnutls-3.5.16

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    echo "You can run build-autotools.sh and build-libtool.sh to update them."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

IS_DARWIN=$(uname -s | grep -i -c darwin)
if [[ ("$IS_DARWIN" -eq "0") ]] && [[ -z $(command -v libtoolize 2>/dev/null) ]]; then
    echo "Some packages require libtool. Please install libtool or libtool-bin."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "GnuTLS requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/addtrust-root-ca.pem" ]]; then
    echo "GnuTLS requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
ADDTRUST_ROOT="$HOME/.cacert/addtrust-root-ca.pem"

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

if ! ./build-libtool.sh
then
    echo "Failed to build Libtool"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build Tasn1"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-expat.sh
then
    echo "Failed to build Expat"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-readline.sh
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-guile.sh
then
    echo "Failed to build Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-p11kit.sh
then
    echo "Failed to build P11-Kit"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** GnuTLS **********"
echo

wget --ca-certificate="$ADDTRUST_ROOT" "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.5/$GNUTLS_TAR" -O "$GNUTLS_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GNUTLS_DIR" &>/dev/null
tar xJf "$GNUTLS_TAR"
cd "$GNUTLS_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="-lhogweed -lnettle -lgmp ${BUILD_LIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --with-unbound-root-key-file --enable-seccomp-tests \
    --disable-openssl-compatibility --disable-ssl2-support --disable-ssl3-support \
    --disable-gtk-doc --disable-gtk-doc-html --disable-gtk-doc-pdf \
    --with-p11-kit --with-tpm --with-libregex \
    --with-libz-prefix="$INSTALL_PREFIX" \
    --with-libiconv-prefix="$INSTALL_PREFIX" \
    --with-libintl-prefix="$INSTALL_PREFIX" \
    --with-libseccomp-prefix="$INSTALL_PREFIX" \
    --with-libunistring-prefix="$INSTALL_PREFIX"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "all" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GnuTLS"
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

    ARTIFACTS=("$GNUTLS_TAR" "$GNUTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnutls.sh 2>&1 | tee build-gnutls.log
    if [[ -e build-gnutls.log ]]; then
        rm -f build-gnutls.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
