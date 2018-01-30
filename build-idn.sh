#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds IDN from sources.

# Use libidn-1.33 for Solaris and OS X... IDN2 causes too
# many problems and too few answers on the mailing list.
IDN_TAR=libidn-1.33.tar.gz
IDN_DIR=libidn-1.33

IDN2_TAR=libidn2-2.0.4.tar.gz
IDN2_DIR=libidn2-2.0.4

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

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "IDN requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

###############################################################################

echo
echo "********** IDN **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libidn/$IDN_TAR" -O "$IDN_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$IDN_DIR" &>/dev/null
gzip -d < "$IDN_TAR" | tar xf -
cd "$IDN_DIR"

if [[ ! -e "configure" ]]; then
    autoreconf --install --force
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to reconfigure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

if [[ "$IS_SOLARIS" -eq "1" ]]; then
  if [[ (-f src/idn2.c) ]]; then
    sed -e '/^#include "error.h"/d' src/idn2.c > src/idn2.c.fixed
    mv src/idn2.c.fixed src/idn2.c
    sed -e '43istatic void error (int status, int errnum, const char *format, ...);' src/idn2.c > src/idn2.c.fixed
    mv src/idn2.c.fixed src/idn2.c

    {
      echo ""
      echo "static void"
      echo "error (int status, int errnum, const char *format, ...)"
      echo "{"
      echo "  va_list args;"
      echo "  va_start(args, format);"
      echo "  vfprintf(stderr, format, args);"
      echo "  va_end(args);"
      echo "  exit(status);"
      echo "}"
      echo ""
    } >> src/idn2.c
    touch -t 197001010000 src/idn2.c
  fi
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --disable-gtk-doc

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# WTF? Why try to build docs when tools are missing???
for mfile in $(find "$PWD" -name 'Makefile'); do
    sed -e 's/HELP2MAN =.*/HELP2MAN = true/g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
    sed -e 's/MAKEINFO =.*/MAKEINFO = true/g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
    touch -t 197001010000 "$mfile"
done

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
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

AUTOMAKE_VERSION=$(automake --version 2>/dev/null | head -n 1)
AUTOMAKE_OK=$(echo $AUTOMAKE_VERSION | grep -c -E "automake * (1\.1[5-9]\.|1\.[3-9]\.)")

if [[ "$AUTOMAKE_OK" -eq "0" ]]; then
    ./build-automake.sh
fi

###############################################################################

echo
echo "********** IDN2 **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libidn/$IDN2_TAR" -O "$IDN2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$IDN2_DIR" &>/dev/null
gzip -d < "$IDN2_TAR" | tar xf -
cd "$IDN2_DIR"

if [[ ! -e "configure" ]]; then
    autoreconf --install --force
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to reconfigure IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --disable-gtk-doc

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# WTF? Why try to build docs when tools are missing???
for mfile in $(find "$PWD" -name 'Makefile'); do
    sed -e 's/HELP2MAN =.*/HELP2MAN = true/g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
    sed -e 's/MAKEINFO =.*/MAKEINFO = true/g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
    touch -t 197001010000 "$mfile"
done

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN2"
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

    ARTIFACTS=("$IDN_TAR" "$IDN_DIR" "$IDN2_TAR" "$IDN2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-idn.sh 2>&1 | tee build-idn.log
    if [[ -e build-idn.log ]]; then
        rm -f build-idn.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
