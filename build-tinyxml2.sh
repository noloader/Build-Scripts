#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds TinyXML from sources.

TXML2_TAR=6.0.0.tar.gz
TXML2_DIR=tinyxml2-6.0.0

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require Autotools. Please install autoconf, automake and libtool."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "TinyXML requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
source ./build-environ.sh

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** TinyXML2 **********"
echo

# https://github.com/leethomason/tinyxml2/archive/6.0.0.tar.gz
wget --ca-certificate="$DIGICERT_ROOT" "https://github.com/leethomason/tinyxml2/archive/$TXML2_TAR" -O "$TXML2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download tinyxml2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$TXML2_DIR" &>/dev/null
gzip -d < "$TXML2_TAR" | tar xf -
cd "$TXML2_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

MAKE_FLAGS=("-j" "$MAKE_JOBS")
MAKE_FLAGS+=("PKG_CONFIG_PATH=${BUILD_PKGCONFIG[*]}")
MAKE_FLAGS+=("CPPFLAGS=${BUILD_CPPFLAGS[*]}")
MAKE_FLAGS+=("CFLAGS=${BUILD_CFLAGS[*]}")
MAKE_FLAGS+=("CXXFLAGS=${BUILD_CXXFLAGS[*]}")
MAKE_FLAGS+=("LDFLAGS=${BUILD_LDFLAGS[*]}")
MAKE_FLAGS+=("LIBS=${BUILD_LIBS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build tinyxml2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("test")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test tinyxml2"
   [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# TODO... fix this simple copy
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S cp tinyxml2.h "$INSTX_PREFIX/include"
    echo "$SUDO_PASSWORD" | sudo -S cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
else
    cp tinyxml2.h "$INSTX_PREFIX/include"
    cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TXML2_TAR" "$TXML2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-expat.sh 2>&1 | tee build-expat.log
    if [[ -e build-expat.log ]]; then
        rm -f build-expat.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
