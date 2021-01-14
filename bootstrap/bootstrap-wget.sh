#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton.
# This script builds Wget, Unistring and OpenSSL from sources.
# This Wget is crippled, but allows bootstrapping a full Wget build.

# Binaries
WGET_TAR=wget-1.21.1.tar.gz
UNISTR_TAR=libunistring-0.9.10.tar.gz
SSL_TAR=openssl-1.0.2u.tar.gz

# Directories
BOOTSTRAP_DIR=$(pwd)
WGET_DIR=wget-1.21.1
UNISTR_DIR=libunistring-0.9.10
SSL_DIR=openssl-1.0.2u

# Install location
PREFIX="$HOME/.build-scripts/wget"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
CACERTDIR="$PREFIX/cacert"
CACERTFILE="$CACERTDIR/cacert.pem"

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

# Make the directories
mkdir -p "$PREFIX" "$LIBDIR" "$CACERTDIR"

###############################################################################

# Autotools on Solaris has an implied requirement for GNU gear. Things fall apart without it.
# Also see https://blogs.oracle.com/partnertech/entry/preparing_for_the_upcoming_removal.
if [[ -d "/usr/gnu/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/gnu/bin"*) ]]; then
        echo
        echo "Adding /usr/gnu/bin to PATH for Solaris"
        export PATH="/usr/gnu/bin:$PATH"
    fi
elif [[ -d "/usr/swf/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/sfw/bin"*) ]]; then
        echo
        echo "Adding /usr/sfw/bin to PATH for Solaris"
        export PATH="/usr/sfw/bin:$PATH"
    fi
elif [[ -d "/usr/ucb/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/ucb/bin"*) ]]; then
        echo
        echo "Adding /usr/ucb/bin to PATH for Solaris"
        export PATH="/usr/ucb/bin:$PATH"
    fi
fi

############################## Misc ##############################

if [[ -z "$CC" ]]
then
    if [[ -n "$(command -v cc 2>/dev/null)" && -n "$(command -v CC 2>/dev/null)" ]]; then
        CC=cc; CXX=CC
    elif [[ -n "$(command -v gcc 2>/dev/null)" ]]; then
        CC=gcc; CXX=g++
    elif [[ -n "$(command -v clang 2>/dev/null)" ]]; then
        CC=clang; CXX=clang++
    fi
fi

if $CC $CFLAGS bitness.c -o /dev/null &>/dev/null; then
    OPT_BITS=64
else
    OPT_BITS=32
fi

if $CC $CFLAGS comptest.c -fPIC -o /dev/null &>/dev/null; then
    OPT_PIC=-fPIC
elif $CC $CFLAGS comptest.c -kPIC -o /dev/null &>/dev/null; then
    OPT_PIC=-kPIC
fi

# Needed for Solaris
if $CC $CFLAGS comptest.c -lresolv -lsocket -lnsl -o /dev/null &>/dev/null; then
    OPT_SOCKET="-lresolv -lsocket -lnsl"
elif $CC $CFLAGS comptest.c -lsocket -lnsl -o /dev/null &>/dev/null; then
    OPT_SOCKET="-lsocket -lnsl"
elif $CC $CFLAGS comptest.c -lsocket -o /dev/null &>/dev/null; then
    OPT_SOCKET="-lsocket"
fi

# Needed for some BSDs
if $CC $CFLAGS comptest.c -ldl -o /dev/null &>/dev/null; then
    OPT_LDL=-ldl
fi

echo
echo "*************************************************"
echo Bootstrap options:
echo "  OPT_BITS: $OPT_BITS"
echo "  OPT_PIC: $OPT_PIC"
echo "  OPT_LDL: $OPT_LDL"
echo "  OPT_SOCKET: $OPT_SOCKET"
echo "*************************************************"

IS_DARWIN=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'darwin')
IS_LINUX=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'linux')
IS_AMD64=$(echo -n "$(uname -m 2>&1)" | grep -i -c -E 'x86_64|amd64')
#IS_SOLARIS=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'sunos')

# DH is 2x to 4x faster with ec_nistp_64_gcc_128, but it is
# only available on x64 machines with uint128 available.
HAVE_INT128=$($CC $CFLAGS -dM -E - </dev/null | grep -i -c "__SIZEOF_INT128__")

if [[ "$IS_AMD64" -ne 0 && "$HAVE_INT128" -ne 0 ]]; then
    OPT_INT128="enable-ec_nistp_64_gcc_128"
fi

# OpenSSL does not honor no-dso. Needed by Unistring and Wget.
OPENSSL_LIBS="$LIBDIR/libssl.a $LIBDIR/libcrypto.a"
UNISTRING_LIBS="$LIBDIR/libunistring.a"

############################## CA Certs ##############################

echo
echo "*************************************************"
echo "Configure CA certs"
echo "*************************************************"
echo

# Copy our copy of cacerts to bootstrap
mkdir -p "$CACERTDIR"
if ! cp cacert.pem "$CACERTDIR"; then
    echo "Failed to install cacert.pem"
    exit 1
fi

echo "Copy cacert.pem to $CACERTFILE"
echo "Done."

############################## OpenSSL ##############################

echo
echo "*************************************************"
echo "Building OpenSSL"
echo "*************************************************"
echo

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$SSL_DIR" || exit 1

    KERNEL_BITS="$OPT_BITS" \
./config \
    --prefix="$PREFIX" \
    --openssldir="$PREFIX" \
    "$OPT_INT128" "$OPT_PIC" -DPEDANTIC \
    no-ssl2 no-ssl3 no-comp no-zlib no-zlib-dynamic \
    no-threads no-shared no-dso no-engine

# This will need to be fixed for BSDs and PowerMac
if ! make depend; then
    echo "Failed to update OpenSSL dependencies"
    exit 1
fi

if ! make -j "$INSTX_JOBS"; then
    echo "Failed to build OpenSSL"
    exit 1
fi

rm -f "$PREFIX/openssl.cnf"

if ! make install_sw; then
    echo "Failed to install OpenSSL"
    exit 1
fi

# OpenSSL does not honor no-engines
rm -rf "$LIBDIR/engines"

# Write essential values
{
    echo "RANDFILE = \$ENV::HOME/.rand"
    echo "certificate = $CACERTDIR/cacert.pem"

} >> "$PREFIX/openssl.cnf"

############################## Unistring ##############################

cd "$BOOTSTRAP_DIR" || exit 1

echo
echo "*************************************************"
echo "Building Unistring"
echo "*************************************************"
echo

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$UNISTR_DIR" || exit 1

    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="$LIBDIR/pkgconfig/" \
    OPENSSL_LIBS="$OPENSSL_LIBS" \
    LIBS="$OPT_SOCKET $OPT_LDL" \
./configure \
    --prefix="$PREFIX" \
    --sysconfdir="$PREFIX/etc" \
    --disable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Unistring"
    exit 1
fi

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Unistring"
    exit 1
fi

if ! make install; then
    echo "Failed to install Unistring"
    exit 1
fi

############################## Wget ##############################

cd "$BOOTSTRAP_DIR" || exit 1

echo
echo "*************************************************"
echo "Building Wget"
echo "*************************************************"
echo

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$WGET_DIR" || exit 1

# Install recipe does not overwrite a config, if present.
if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="$LIBDIR/pkgconfig/" \
    OPENSSL_LIBS="$OPENSSL_LIBS" \
    LIBS="$UNISTRING_LIBS $OPENSSL_LIBS $OPT_SOCKET $OPT_LDL" \
./configure \
    --prefix="$PREFIX" \
    --sysconfdir="$PREFIX/etc" \
    --with-libunistring-prefix="${PREFIX}" \
    --with-libssl-prefix="${PREFIX}" \
    --with-ssl=openssl \
    --with-openssl=yes \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn \
    --without-cares \
    --disable-pcre \
    --disable-pcre2 \
    --disable-nls \
    --disable-iri \
    --disable-ntlm \
    --disable-opie

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Wget"
    exit 1
fi

# Fix makefiles. No shared objects.
IFS= find "$PWD" -iname 'Makefile' -print | while read -r file
do
    sed "s|-lssl|$LIBDIR/libssl.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed "s|-lcrypto|$LIBDIR/libcrypto.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed "s|-lunistring|$LIBDIR/libunistring.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Wget"
    exit 1
fi

# Remove old rc file.
rm -f "$PREFIX/etc/wgetrc"

if ! make install; then
    echo "Failed to install Wget"
    exit 1
fi

# Wget configuration file
{
    echo ""
    echo "# cacert.pem location"
    echo "ca_directory = $PREFIX/cacert/"
    echo "ca_certificate = $PREFIX/cacert/cacert.pem"
    echo ""
} >> "$PREFIX/etc/wgetrc"

# Cleanup
if true; then
    cd "$CURR_DIR" || exit 1
    rm -rf "$WGET_DIR"
    rm -rf "$UNISTR_DIR"
    rm -rf "$SSL_DIR"
fi

exit 0
