#!/usr/bin/env bash

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

# OpenSSH can only use OpenSSL 1.0.2 at the moment
OPENSSL_TAR=openssl-1.0.2k.tar.gz
OPENSSL_DIR=openssl-1.0.2k
#OPENSSL_TAR=openssl-1.1.0e.tar.gz
#OPENSSL_DIR=openssl-1.1.0e

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11

BZ2_TAR=bzip2-1.0.6.tar.gz
BZ2_DIR=bzip2-1.0.6

READLN_TAR=readline-7.0.tar.gz
READLN_DIR=readline-7.0

UNISTR_TAR=libunistring-0.9.7.tar.gz
UNISTR_DIR=libunistring-0.9.7

ICONV_TAR=libiconv-1.15.tar.gz
ICONV_DIR=libiconv-1.15

IDN2_TAR=libidn2-0.16.tar.gz
IDN2_DIR=libidn2-0.16

PCRE_TAR=pcre-8.40.tar.gz
PCRE_DIR=pcre-8.40

PCRE2_TAR=pcre2-10.23.tar.gz
PCRE2_DIR=pcre2-10.23

CURL_TAR=curl-7.53.1.tar.gz
CURL_DIR=curl-7.53.1

GIT_TAR=v2.12.2.tar.gz
GIT_DIR=git-2.12.2

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

if [[ -z `which autoreconf` ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

if [[ -z `which msgfmt` ]]; then
    echo "Git requires msgfmt. Please install gettext."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "If you enter a sudo password, then it will be used for installation."
echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
echo "To avoid sudo and the password, just press ENTER and they won't be used."
read -s -p "Please enter password for sudo: " SUDO_PASSWWORD
echo

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_LINUX=$(echo -n "$THIS_SYSTEM" | grep -i -c linux)
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c cygwin)
IS_MINGW=$(echo -n "$THIS_SYSTEM" | grep -i -c mingw)
IS_OPENBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c openbsd)
IS_DRAGONFLY=$(echo -n "$THIS_SYSTEM" | grep -i -c dragonfly)
IS_FREEBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c freebsd)
IS_NETBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c netbsd)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)

if [[ ("$IS_FREEBSD" -eq "1" || "$IS_OPENBSD" -eq "1" || "$IS_NETBSD" -eq "1" || "$IS_DRAGONFLY" -eq "1" || "$IS_SOLARIS" -eq "1") ]]; then
    if [[ !(-z `which gmake 2>/dev/null | grep -v 'no gmake'`) ]]; then
        MAKE=gmake
    else
        MAKE=make
    fi
else
    MAKE=make
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -eq "1" ]]; then
    SH_KBITS=64
    SH_MARCH=-m64
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    INSTALL_LIBDIR_DIR="lib64"
elif [[ "$IS_64BIT" -eq "1" ]]; then
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_KBITS=64
        SH_MARCH=-m64
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        INSTALL_LIBDIR_DIR="lib"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_KBITS=64
        SH_MARCH=-m64
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
        INSTALL_LIBDIR_DIR="lib64"
    else
        SH_KBITS=64
        SH_MARCH=-m64
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        INSTALL_LIBDIR_DIR="lib"
    fi
else
    SH_KBITS=32
    SH_MARCH=-m32
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    INSTALL_LIBDIR_DIR="lib"
fi

if [[ -z "$CC" ]]; then CC=`which cc`; fi

GCC_46_OR_EARLIER=$("$CC" -v 2>&1 | egrep -i -c 'gcc version ([2-3]\.[0-9]|4\.[0-6])')
if [[ "$GCC_46_OR_EARLIER" -eq "1" ]]; then
	SH_MARCH=
fi

echo
echo "********** libdir **********"
echo
echo "Using libdir $INSTALL_LIBDIR"

###############################################################################

echo
echo "********** zLib **********"
echo

wget "http://www.zlib.net/$ZLIB_TAR" -O "$ZLIB_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download zLib"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$ZLIB_DIR" &>/dev/null
tar -xzf "$ZLIB_TAR"
cd "$ZLIB_DIR"

SH_LDLIBS=("-ldl -lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure zLib"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build zLib"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** Bzip **********"
echo

wget "http://www.bzip.org/1.0.6/$BZ2_TAR" -O "$BZ2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Bzip"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$BZ2_DIR" &>/dev/null
tar -xzf "$BZ2_TAR"
cd "$BZ2_DIR"

# Fix Bzip install paths
cp Makefile Makefile.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Fix Bzip cpu architecture
cp Makefile Makefile.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
cp Makefile Makefile.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Add RPATH
cp Makefile Makefile.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build Bzip"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install PREFIX="$INSTALL_PREFIX" LIBDIR="$INSTALL_LIBDIR")
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** Unistring **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://ftp.gnu.org/gnu/libunistring/$UNISTR_TAR" --no-check-certificate -O "$UNISTR_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$UNISTR_DIR" &>/dev/null
tar -xzf "$UNISTR_TAR"
cd "$UNISTR_DIR"

SH_LDLIBS=("-ldl -lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** Readline **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://ftp.gnu.org/gnu/readline/$READLN_TAR" --no-check-certificate -O "$READLN_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Readline"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$READLN_DIR" &>/dev/null
tar -xzf "$READLN_TAR"
cd "$READLN_DIR"

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Readline"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build Readline"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** iConvert **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://ftp.gnu.org/pub/gnu/libiconv/$ICONV_TAR" --no-check-certificate -O "$ICONV_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download iConvert"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
tar -xzf "$ICONV_TAR"
cd "$ICONV_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure iConvert"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build iConvert"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** IDN2 **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://alpha.gnu.org/gnu/libidn/$IDN2_TAR" --no-check-certificate -O "$IDN2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$IDN2_DIR" &>/dev/null
tar -xzf "$IDN2_TAR"
cd "$IDN2_DIR"

if [[ "$IS_SOLARIS" -eq "1" ]]; then
    cp src/idn2.c src/idn2.c.orig
    sed '/^#include "error.h"/d' src/idn2.c.orig > src/idn2.c
    cp src/idn2.c src/idn2.c.orig
    sed '43istatic void error (int status, int errnum, const char *format, ...);' src/idn2.c.orig > src/idn2.c
    rm src/idn2.c.orig

    echo "" >> src/idn2.c
    echo "static void" >> src/idn2.c
    echo "error (int status, int errnum, const char *format, ...)" >> src/idn2.c
    echo "{" >> src/idn2.c
    echo "  va_list args;" >> src/idn2.c
    echo "  va_start(args, format);" >> src/idn2.c
    echo "  vfprintf(stderr, format, args);" >> src/idn2.c
    echo "  va_end(args);" >> src/idn2.c
    echo "  exit(status);" >> src/idn2.c
    echo "}" >> src/idn2.c
    echo "" >> src/idn2.c
fi

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build IDN"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** OpenSSL **********"
echo

# wget on Ubuntu 16 cannot validate against Let's Encrypt certificate
wget "https://www.openssl.org/source/$OPENSSL_TAR" --no-check-certificate -O "$OPENSSL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download OpenSSL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
tar -xzf "$OPENSSL_TAR"
cd "$OPENSSL_DIR"

# OpenSSL and enable-ec_nistp_64_gcc_128 option
IS_X86_64=$(uname -m 2>&1 | egrep -i -c "(amd64|x86_64)")
if [[ "$SH_KBITS" -eq "32" ]]; then IS_X86_64=0; fi

CONFIG=./config
CONFIG_FLAGS=("no-ssl2" "no-ssl3" "no-comp" "shared" "-DNDEBUG" "-Wl,-rpath,$INSTALL_LIBDIR"
        "--prefix=$INSTALL_PREFIX" "--openssldir=$INSTALL_PREFIX" "--libdir=$INSTALL_LIBDIR_DIR")
if [[ "$IS_X86_64" -eq "1" ]]; then
    CONFIG_FLAGS+=("enable-ec_nistp_64_gcc_128")
fi

KERNEL_BITS="$SH_KBITS" "$CONFIG" "${CONFIG_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure OpenSSL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4 depend)
"$MAKE" "${MAKE_FLAGS[@]}"

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build OpenSSL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install_sw)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** PCRE **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" --no-check-certificate -O "$PCRE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$PCRE_DIR" &>/dev/null
tar -xzf "$PCRE_TAR"
cd "$PCRE_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lz" "-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --enable-pcregrep-libz --enable-pcregrep-libbz2 \
    --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4 all)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build PCRE"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** PCRE2 **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" --no-check-certificate -O "$PCRE2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE2"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
tar -xzf "$PCRE2_TAR"
cd "$PCRE2_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lz" "-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE2"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4 all)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build PCRE2"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** cURL **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "https://curl.haxx.se/download/$CURL_TAR" --no-check-certificate -O "$CURL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download cURL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$CURL_DIR" &>/dev/null
tar -xzf "$CURL_TAR"
cd "$CURL_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lidn2" "-lssl" "-lcrypto" "-lz" "-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-shared --enable-ipv6 --with-nghttp2 --with-ssl="$INSTALL_PREFIX" \
    --with-libidn2="$INSTALL_PREFIX" --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure cURL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build cURL"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** Git **********"
echo

# wget on Ubuntu 16 cannot validate against DigiCert certificate
wget "https://github.com/git/git/archive/$GIT_TAR" --no-check-certificate -O "$GIT_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Git"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$GIT_DIR" &>/dev/null
tar -xzf "$GIT_TAR"
cd "$GIT_DIR"

make configure

if [[ "$?" -ne "0" ]]; then
    echo "Failed to make configure Git"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

# "Instruct Git to use pthread library?", http://stackoverflow.com/q/43080417/
for file in $(find `pwd` -iname 'Makefile*')
do 
    cp "$file" "$file.orig"
    sed 's|-lrt|-lrt -lpthread|g' "$file.orig" > "$file"
    rm "$file.orig"
done

# Various Solaris 11 workarounds
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    for file in $(find `pwd` -iname 'Makefile*')
    do 
        cp "$file" "$file.orig"
        sed 's|-lsocket|-lnsl -lsocket|g' "$file.orig" > "$file"
        cp "$file" "$file.orig"
        sed 's|/usr/ucb/install|install|g' "$file.orig" > "$file"
        rm "$file.orig"
    done
    for file in $(find `pwd` -iname 'config*')
    do 
        cp "$file" "$file.orig"
        sed 's|-lsocket|-lnsl -lsocket|g' "$file.orig" > "$file"
        cp "$file" "$file.orig"
        sed 's|/usr/ucb/install|install|g' "$file.orig" > "$file"
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

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lssl" "-lcrypto" "-lz" "-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
    ./configure --enable-pthreads --with-lib="$INSTALL_LIBDIR" --with-openssl="$INSTALL_PREFIX" \
    --with-curl="$INSTALL_PREFIX" --with-libpcre="$INSTALL_PREFIX" --with-zlib="$INSTALL_PREFIX" \
    --with-iconv="$INSTALL_PREFIX" --with-perl="$SH_PERL" --prefix="$INSTALL_PREFIX"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Git"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=(-j 4 all)
if [[ ! -z `which asciidoc 2>/dev/null | grep -v 'no asciidoc'` ]]; then
    if [[ ! -z `which makeinfo 2>/dev/null | grep -v 'no makeinfo'` ]]; then
        MAKE_FLAGS+=("man")
    fi
    if [[ ! -z `which xmlto 2>/dev/null | grep -v 'no xmlto'` ]]; then
        MAKE_FLAGS+=("info" "html")
    fi
fi

"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -eq "1" ]]; then
    echo "Failed to build Git"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=(install)
if [[ ! -z `which asciidoc 2>/dev/null | grep -v 'no asciidoc'` ]]; then
    if [[ ! -z `which makeinfo 2>/dev/null | grep -v 'no makeinfo'` ]]; then
        MAKE_FLAGS+=("install-man")
    fi
    if [[ ! -z `which xmlto 2>/dev/null | grep -v 'no xmlto'` ]]; then
        MAKE_FLAGS+=("install-info" "install-html")
    fi
fi

if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd ..

###############################################################################

echo
echo "********** Cleanup **********"
echo

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR" "$UNISTR_TAR" "$UNISTR_DIR" "$READLN_TAR" "$READLN_DIR"
            "$PCRE_TAR" "$PCRE_DIR" "$PCRE2_TAR" "$PCRE2_DIR" "$ZLIB_TAR" "$ZLIB_DIR"  "$BZ2_TAR" "$BZ2_DIR"
            "$IDN2_TAR" "$IDN2_DIR" "$ICONV_TAR" "$ICONV_DIR" "$CURL_TAR" "$CURL_DIR" "$GIT_TAR" "$GIT_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-git.sh 2>&1 | tee build-git.log
    if [[ -e build-git.log ]]; then
        rm build-git.log
    fi
fi

[[ "$0" = "$BASH_SOURCE" ]] && exit 0 || return 0
