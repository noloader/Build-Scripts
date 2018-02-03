#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds IDN and IDN2 from sources.

IDN_TAR=libidn-1.33.tar.gz
IDN_DIR=libidn-1.33

IDN2_TAR=libidn2-2.0.4.tar.gz
IDN2_DIR=libidn2-2.0.4

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
source ./build-environ.sh

PKG_NAME1=libidn
PKG_NAME2=libidn2

if [[ -e "$INSTX_CACHE/$PKG_NAME1" && -e "$INSTX_CACHE/$PKG_NAME2" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME1 and $PKG_NAME2 are already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

###############################################################################

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

# Avoid reconfiguring.
if [[ ! -e "configure" ]]; then
    ./bootstrap.sh
    if [[ "$?" -ne "0" ]]; then
        echo "Failed to reconfigure IDN"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

# Fix AM_INIT_AUTOMAKE
sed -e 's/^AM_INIT_AUTOMAKE.*/AM_INIT_AUTOMAKE/g' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Remove useless directive
sed -e '/AM_SILENT_RULES/d' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Get rid of all docs Makefiles
sed -e '/^  doc\//d' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Set time in the past to avoid re-configuration
touch -t 197001010000 configure.ac

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
    --enable-shared \
    --disable-gtk-doc --disable-gtk-doc-html --disable-gtk-doc-pdf

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

for mfile in $(find "$PWD" -name Makefile);
do
    # Get rid of all doc/ directories
    sed -e 's| doc | |g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
done

rm -rf doc/ 2>/dev/null

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

# Avoid reconfiguring.
if [[ ! -e "configure" ]]; then
    ./bootstrap.sh
    if [[ "$?" -ne "0" ]]; then
        echo "Failed to reconfigure IDN2"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

# Fix AM_INIT_AUTOMAKE
sed -e 's/^AM_INIT_AUTOMAKE.*/AM_INIT_AUTOMAKE/g' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Remove useless directive
sed -e '/AM_SILENT_RULES/d' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Get rid of all docs Makefiles
sed -e '/^  doc\//d' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac
# Set time in the past to avoid re-configuration
touch -t 197001010000 configure.ac

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure > configure.fixed
mv configure.fixed configure; chmod +x configure

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --disable-gtk-doc --disable-gtk-doc-html --disable-gtk-doc-pdf

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

for mfile in $(find "$PWD" -name Makefile);
do
    # Get rid of most doc/ directories
    sed -e 's| doc | |g' "$mfile" > "$mfile.fixed"
    mv "$mfile.fixed" "$mfile"
done

# And the last vestige of doc/
sed -e 's|^am__append_2.*|am__append_2 =| g' Makefile > Makefile.fixed
mv Makefile.fixed Makefile

rm -rf doc/ >/dev/null

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

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME1"
touch "$INSTX_CACHE/$PKG_NAME2"

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
