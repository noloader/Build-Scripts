#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

GNUTLS_VER=3.6.15
GNUTLS_XZ=gnutls-${GNUTLS_VER}.tar.xz
GNUTLS_TAR=gnutls-${GNUTLS_VER}.tar
GNUTLS_DIR=gnutls-${GNUTLS_VER}
PKG_NAME=gnutls

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "${SUDO_PASSWORD_DONE}" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA certs"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build libtasn1"
    exit 1
fi

###############################################################################

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-gettext-final.sh
then
    echo echo "Failed to build GetText final"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    exit 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    exit 1
fi

###############################################################################

if ! ./build-p11kit.sh
then
    echo "Failed to build P11-Kit"
    exit 1
fi

###############################################################################

if [[ -z "$(command -v datefudge 2>/dev/null)" ]]
then
    echo ""
    echo "datefudge not found. Some tests will be skipped."
    echo "To fix this issue, please install datefudge."
fi

###############################################################################

echo ""
echo "========================================"
echo "================ GnuTLS ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "GnuTLS ${GNUTLS_VER}..."

if ! "$WGET" -q -O "$GNUTLS_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/$GNUTLS_XZ"
then
    echo "Failed to download GnuTLS"
    exit 1
fi

rm -rf "$GNUTLS_TAR" "$GNUTLS_DIR" &>/dev/null
unxz "$GNUTLS_XZ" && tar -xf "$GNUTLS_TAR"
cd "$GNUTLS_DIR"

if [[ -e ../patch/gnutls.patch ]]; then
    patch -u -p0 < ../patch/gnutls.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

GNUTLS_PKGCONFIG="${INSTX_PKGCONFIG}"
GNUTLS_CPPFLAGS="${INSTX_CPPFLAGS}"
GNUTLS_ASFLAGS="${INSTX_ASFLAGS}"
GNUTLS_CFLAGS="${INSTX_CFLAGS}"
GNUTLS_CXXFLAGS="${INSTX_CXXFLAGS}"
GNUTLS_LDFLAGS="${INSTX_LDFLAGS}"
GNUTLS_LIBS="${INSTX_LDLIBS}"

# Solaris is a tab bit stricter than libc
if [[ "$IS_SOLARIS" -ne 0 ]]; then
    # Don't use CPPFLAGS. Options will cross-pollinate into CXXFLAGS.
    GNUTLS_CFLAGS+=" -D_XOPEN_SOURCE=600 -std=gnu99"
fi

# We should probably include --disable-anon-authentication below

    PKG_CONFIG_PATH="${GNUTLS_PKGCONFIG}" \
    CPPFLAGS="${GNUTLS_CPPFLAGS}" \
    ASFLAGS="${GNUTLS_ASFLAGS}" \
    CFLAGS="${GNUTLS_CFLAGS}" \
    CXXFLAGS="${GNUTLS_CXXFLAGS}" \
    LDFLAGS="${GNUTLS_LDFLAGS}" \
    LIBS="${GNUTLS_LIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static \
    --enable-shared \
    --enable-seccomp-tests \
    --enable-sha1-support \
    --disable-guile \
    --disable-ssl2-support \
    --disable-ssl3-support \
    --disable-padlock \
    --disable-doc \
    --disable-full-test-suite \
    --with-p11-kit \
    --with-libregex \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}" \
    --with-libseccomp-prefix="${INSTX_PREFIX}" \
    --with-libcrypto-prefix="${INSTX_PREFIX}" \
    --with-unbound-root-key-file="$INSTX_ROOTKEY_FILE" \
    --with-default-trust-store-file="$INSTX_CACERT_FILE" \
    --with-default-trust-store-dir="$INSTX_CACERT_PATH"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuTLS"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

IFS= find . -name 'Makefile' -print | while read -r file
do
    # Make console output more readable...
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

IFS= find ./tests -name 'Makefile' -print | while read -r file
do
    # Test suite does not compile with NDEBUG defined.
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    sed -e 's| -DNDEBUG||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

IFS= find . -name '*.la' -print | while read -r file
do
    # Make console output more readable...
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

IFS= find . -name '*.sh' -print | while read -r file
do
    # Fix shell
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    sed -e 's|#!/bin/sh|#!/usr/bin/env bash|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if [[ "$IS_SOLARIS" -ne 0 ]]
then
    # Solaris netstat is different then GNU netstat
    echo "patching common.sh..."
    file=tests/scripts/common.sh
    cp -p "$file" "$file.fixed"
    sed -e 's|PFCMD -anl|PFCMD -an|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
fi
echo ""

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to build GnuTLS"
    echo "**********************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test GnuTLS"
    echo "**********************"

    bash ../collect-logs.sh
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GNUTLS_XZ" "$GNUTLS_TAR" "$GNUTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
