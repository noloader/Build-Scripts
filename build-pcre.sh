#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PCRE and PCRE2 from sources.

PCRE_TAR=pcre-8.41.tar.gz
PCRE_DIR=pcre-8.41
PKG_NAME1=pcre

PCRE2_TAR=pcre2-10.30.tar.gz
PCRE2_DIR=pcre2-10.30
PKG_NAME2=pcre2

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

if [[ -e "$INSTX_CACHE/$PKG_NAME1" && -e "$INSTX_CACHE/$PKG_NAME2" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME1 and $PKG_NAME2 are already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** PCRE **********"
echo

# This fails when Wget < 1.14
wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" -O "$PCRE_TAR"

# Dowload over insecure channel
if [[ "$?" -ne "0" ]]; then
    echo "Attempting download over insecure channel."
    wget --no-check-certificate "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" -O "$PCRE_TAR"
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE_DIR" &>/dev/null
gzip -d < "$PCRE_TAR" | tar xf -
cd "$PCRE_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --enable-pcregrep-libz --enable-jit --enable-pcregrep-libbz2

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME1"

###############################################################################

echo
echo "********** PCRE2 **********"
echo

# This fails when Wget < 1.14
wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" -O "$PCRE2_TAR"

# Dowload over insecure channel
if [[ "$?" -ne "0" ]]; then
    echo "Attempting download over insecure channel."
    wget --no-check-certificate "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" -O "$PCRE2_TAR"
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME2"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PCRE_TAR" "$PCRE_DIR" "$PCRE2_TAR" "$PCRE2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pcre.sh 2>&1 | tee build-pcre.log
    if [[ -e build-pcre.log ]]; then
        rm -f build-pcre.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
