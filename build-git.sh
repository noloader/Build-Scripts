#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Git and its dependencies from sources.

GIT_TAR=v2.16.1.tar.gz
GIT_DIR=git-2.16.1

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

DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"
if [[ ! -f "$DIGICERT_ROOT" ]]; then
    echo "Git requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Required
if ! perl -MExtUtils::MakeMaker -e1 2>/dev/null
then
    echo ""
    echo "Git requires Perl's ExtUtils::MakeMaker."
    echo "To fix this issue, please install ExtUtils-MakeMaker."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if [[ "$IS_CYGWIN" -eq "1" ]]; then

if ! ./build-termcap.sh
then
    echo "Failed to build Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

fi  # IS_CYGWIN

###############################################################################

if ! ./build-readline.sh
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

# For libint.h, https://stackoverflow.com/q/11370684/608639
if ! ./build-gettext.sh
then
    echo "Failed to build GetText"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-idn.sh
then
    echo "Failed to build IDN and IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre.sh
then
    echo "Failed to build PCRE and PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-curl.sh
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Git **********"
echo

wget --ca-certificate="$DIGICERT_ROOT" "https://github.com/git/git/archive/$GIT_TAR" -O "$GIT_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GIT_DIR" &>/dev/null
gzip -d < "$GIT_TAR" | tar xf -
cd "$GIT_DIR"

if ! "$MAKE" configure
then
    echo "Failed to make configure Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# "Instruct Git to use pthread library?", http://stackoverflow.com/q/43080417/
for file in $(find "$PWD" -name 'Makefile*')
do
    cp "$file" "$file.orig"
    sed -e 's|-lrt|-lrt -lpthread|g' "$file.orig" > "$file"
    rm "$file.orig"
done

# Various Solaris 11 workarounds
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    for file in $(find "$PWD" -name 'Makefile*')
    do
        cp "$file" "$file.orig"
        sed -e 's|-lsocket|-lnsl -lsocket|g' "$file.orig" > "$file"
        cp "$file" "$file.orig"
        sed -e 's|/usr/ucb/install|install|g' "$file.orig" > "$file"
        rm "$file.orig"
    done
    for file in $(find "$PWD" -name 'config*')
    do
        cp "$file" "$file.orig"
        sed -e 's|-lsocket|-lnsl -lsocket|g' "$file.orig" > "$file"
        cp "$file" "$file.orig"
        sed -e 's|/usr/ucb/install|install|g' "$file.orig" > "$file"
        rm "$file.orig"
    done
fi

if [[ -e /usr/local/bin/perl ]]; then
    SH_PERL=/usr/local/bin/perl
elif [[ -e /usr/bin/perl ]]; then
    SH_PERL=/usr/bin/perl
else
    SH_PERL=perl
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    PERL="$SH_PERL" CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="-lssl -lcrypto -lz ${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --with-lib="$INSTX_LIBDIR" \
    --enable-pthreads --with-openssl="$INSTX_PREFIX" \
    --with-curl="$INSTX_PREFIX" --with-libpcre="$INSTX_PREFIX" \
    --with-zlib="$INSTX_PREFIX" --with-iconv="$INSTX_PREFIX" \
    --with-perl="$SH_PERL"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("-j" "$MAKE_JOBS")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("install")

# Git builds things during install, and they end up root:root.
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S chmod -R 0777 ./*
else
    "$MAKE" "${MAKE_FLAGS[@]}"
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

    ARTIFACTS=("$GIT_TAR" "$GIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-git.sh 2>&1 | tee build-git.log
    if [[ -e build-git.log ]]; then
        rm -f build-git.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
