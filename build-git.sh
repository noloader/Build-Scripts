#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Git and its dependencies from sources.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

# OpenSSH can only use OpenSSL 1.0.2 at the moment
OPENSSL_TAR=openssl-1.0.2l.tar.gz
OPENSSL_DIR=openssl-1.0.2l
#OPENSSL_TAR=openssl-1.1.0e.tar.gz
#OPENSSL_DIR=openssl-1.1.0e

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11

BZ2_TAR=bzip2-1.0.6.tar.gz
BZ2_DIR=bzip2-1.0.6

TERMCAP_TAR=termcap-1.3.1.tar.gz
TERMCAP_DIR=termcap-1.3.1

READLN_TAR=readline-7.0.tar.gz
READLN_DIR=readline-7.0

UNISTR_TAR=libunistring-0.9.7.tar.gz
UNISTR_DIR=libunistring-0.9.7

ICONV_TAR=libiconv-1.15.tar.gz
ICONV_DIR=libiconv-1.15

# Use libidn-1.33 for Solaris and OS X... IDN2 causes too
# many problems and too few answers on the mailing list.
IDN_TAR=libidn-1.33.tar.gz
IDN_DIR=libidn-1.33

PCRE_TAR=pcre-8.41.tar.gz
PCRE_DIR=pcre-8.41

PCRE2_TAR=pcre2-10.30.tar.gz
PCRE2_DIR=pcre2-10.30

CURL_TAR=curl-7.56.0.tar.gz
CURL_DIR=curl-7.56.0

GIT_TAR=v2.14.2.tar.gz
GIT_DIR=git-2.14.2

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs
MAKE_JOBS=4

# Unset to avoid using an existing trust store when configuring cURL.
# No trust store will be supplied for some OSes, like Solaris.
# Also see '/usr/bin/curl-config --ca' and '/usr/bin/curl-config --configure'
USE_TRUST_STORE=1

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

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Git requires gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v msgfmt 2>/dev/null) ]]; then
    echo "Git requires msgfmt. Please install msgfmt."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/globalsign-root-r1.pem" ]]; then
    echo "Wget requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "Wget requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/identrust-root-x3.pem" ]]; then
    echo "Wget requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

GLOBALSIGN_ROOT="$HOME/.cacert/globalsign-root-r1.pem"
LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"
DIGITRUST_ROOT="$HOME/.cacert/digitrust-root-ca.pem"
DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"

###############################################################################

echo
echo "If you enter a sudo password, then it will be used for installation."
echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
echo "To avoid sudo and the password, just press ENTER and they won't be used."
read -r -s -p "Please enter password for sudo: " SUDO_PASSWWORD
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

# The BSDs and Solaris should have GMake installed if its needed
if [[ $(command -v gmake 2>/dev/null) ]]; then
    MAKE="gmake"
else
    MAKE="make"
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -eq "1" ]]; then
    SH_KBITS="64"
    SH_MARCH="-m64"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    INSTALL_LIBDIR_DIR="lib64"
elif [[ "$IS_64BIT" -eq "1" ]]; then
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_KBITS="64"
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        INSTALL_LIBDIR_DIR="lib"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_KBITS="64"
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
        INSTALL_LIBDIR_DIR="lib64"
    else
        SH_KBITS="64"
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        INSTALL_LIBDIR_DIR="lib"
    fi
else
    SH_KBITS="32"
    SH_MARCH="-m32"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    INSTALL_LIBDIR_DIR="lib"
fi

if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi

MARCH_ERROR=$($CC $SH_MARCH -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$MARCH_ERROR" -ne "0" ]]; then
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
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$ZLIB_DIR" &>/dev/null
gzip -d < "$ZLIB_TAR" | tar xf -
cd "$ZLIB_DIR"

if [[ "$IS_CYGWIN" -ne "0" ]]; then
    if [[ -f "gzguts.h" ]]; then
        sed -i 's/defined(_WIN32) || defined(__CYGWIN__)/defined(_WIN32)/g' gzguts.h
    fi
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** Bzip **********"
echo

wget "http://www.bzip.org/1.0.6/$BZ2_TAR" -O "$BZ2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$BZ2_DIR" &>/dev/null
gzip -d < "$BZ2_TAR" | tar xf -
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

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install "PREFIX=$INSTALL_PREFIX" "LIBDIR=$INSTALL_LIBDIR")
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** Unistring **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libunistring/$UNISTR_TAR" -O "$UNISTR_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$UNISTR_DIR"

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

if [[ "$IS_CYGWIN" -eq "1" ]]; then

echo
echo "********** Termcap **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/termcap/$TERMCAP_TAR" -O "$TERMCAP_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$TERMCAP_DIR" &>/dev/null
gzip -d < "$TERMCAP_TAR" | tar xf -
cd "$TERMCAP_DIR"

sed -i -e '42i#include <unistd.h>' tparam.c

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-install-termcap --prefix="$INSTALL_PREFIX" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

fi

###############################################################################

echo
echo "********** Readline **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/readline/$READLN_TAR" -O "$READLN_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$READLN_DIR" &>/dev/null
gzip -d < "$READLN_TAR" | tar xf -
cd "$READLN_DIR"

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** iConvert **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/pub/gnu/libiconv/$ICONV_TAR" -O "$ICONV_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download iConvert"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
gzip -d < "$ICONV_TAR" | tar xf -
cd "$ICONV_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure iConvert"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

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

if [[ "$IS_SOLARIS" -eq "1" ]]; then
  if [[ (-f src/idn2.c) ]]; then
    cp src/idn2.c src/idn2.c.orig
    sed '/^#include "error.h"/d' src/idn2.c.orig > src/idn2.c
    cp src/idn2.c src/idn2.c.orig
    sed '43istatic void error (int status, int errnum, const char *format, ...);' src/idn2.c.orig > src/idn2.c
    rm src/idn2.c.orig

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
  fi
fi

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

# Darwin is mostly fucked up at the moment. Also see
# http://lists.gnu.org/archive/html/help-libidn/2017-10/msg00002.html
if [[ "$IS_DARWIN" -ne "0" ]]; then
    sed -i "" 's|$AR cru|$AR $ARFLAGS|g' configure
    sed -i "" 's|${AR_FLAGS=cru}|${AR_FLAGS=-static -o }|g' configure
    #sed -i "" 's|$AR cru|$AR $ARFLAGS|g' aclocal.m4
    #sed -i "" 's|$AR cr|$AR $ARFLAGS|g' aclocal.m4
    #sed -i "" 's|$AR cru|$AR $ARFLAGS|g' m4/libtool.m4
    #sed -i "" 's|$AR cr|$AR $ARFLAGS|g' m4/libtool.m4
    #sed -i "" 's|${AR_FLAGS=cru}|${AR_FLAGS=-static -o }|g' m4/libtool.m4

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
    AR="/usr/bin/libtool" ARFLAGS="-static -o " \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

    for mfile in $(find "$PWD" -iname 'Makefile'); do
        echo "Fixing makefile $mfile"
        sed -i "" 's|AR = ar|AR = /usr/bin/libtool|g' "$mfile"
        sed -i "" 's|ARFLAGS = cru|ARFLAGS = -static -o |g' "$mfile"
        sed -i "" 's|ARFLAGS = cr|ARFLAGS = -static -o |g' "$mfile"
    done

    #for sfile in $(find "$PWD" -iname '*.sh'); do
    #    echo "Fixing script $sfile"
    #    sed -i "" 's|$AR cru |$AR $ARFLAGS |g' "$sfile"
    #    sed -i "" 's|$AR cr |$AR $ARFLAGS |g' "$sfile"
    #done

else

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared

fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** OpenSSL **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://www.openssl.org/source/$OPENSSL_TAR" -O "$OPENSSL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
gzip -d < "$OPENSSL_TAR" | tar xf -
cd "$OPENSSL_DIR"

# OpenSSL and enable-ec_nistp_64_gcc_128 option
IS_X86_64=$(uname -m 2>&1 | grep -E -i -c "(amd64|x86_64)")
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
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(depend)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL dependencies"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install_sw)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** PCRE **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" -O "$PCRE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE_DIR" &>/dev/null
gzip -d < "$PCRE_TAR" | tar xf -
cd "$PCRE_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lz" "-ldl" "-lpthread")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared --enable-pcregrep-libz --enable-jit --enable-pcregrep-libbz2

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS" all)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** PCRE2 **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" -O "$PCRE2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lz" "-ldl" "-lpthread")

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS" all)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** cURL **********"
echo

wget --ca-certificate="$GLOBALSIGN_ROOT" "https://curl.haxx.se/download/$CURL_TAR" -O "$CURL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$CURL_DIR" &>/dev/null
gzip -d < "$CURL_TAR" | tar xf -
cd "$CURL_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lidn2" "-lssl" "-lcrypto" "-lz" "-ldl" "-lpthread")

if [[ ("$IS_SOLARIS" -ne "0" && "$USE_TRUST_STORE" -ne "0") ]]; then
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared --without-ca-bundle \
    --with-ca-path=/etc/openssl/certs --enable-ipv6 \
    --with-nghttp2 --with-ssl="$INSTALL_PREFIX" \
    --with-libidn2="$INSTALL_PREFIX"
else
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared --enable-ipv6 --with-nghttp2 --with-ssl="$INSTALL_PREFIX" \
    --with-libidn2="$INSTALL_PREFIX"
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install)
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

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
for file in $(find "$PWD" -iname 'Makefile*')
do
    cp "$file" "$file.orig"
    sed 's|-lrt|-lrt -lpthread|g' "$file.orig" > "$file"
    rm "$file.orig"
done

# Various Solaris 11 workarounds
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    for file in $(find "$PWD" -iname 'Makefile*')
    do
        cp "$file" "$file.orig"
        sed 's|-lsocket|-lnsl -lsocket|g' "$file.orig" > "$file"
        cp "$file" "$file.orig"
        sed 's|/usr/ucb/install|install|g' "$file.orig" > "$file"
        rm "$file.orig"
    done
    for file in $(find "$PWD" -iname 'config*')
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

    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --with-lib="$INSTALL_LIBDIR" \
    --enable-pthreads --with-openssl="$INSTALL_PREFIX" \
    --with-curl="$INSTALL_PREFIX" --with-libpcre="$INSTALL_PREFIX" \
    --with-zlib="$INSTALL_PREFIX" --with-iconv="$INSTALL_PREFIX" \
    --with-perl="$SH_PERL"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=(-j "$MAKE_JOBS" all)
if [[ $(command -v asciidoc 2>/dev/null) ]]; then
    if [[ $(command -v makeinfo 2>/dev/null) ]]; then
        MAKE_FLAGS+=("man")
    fi
    if [[ $(command -v xmlto 2>/dev/null) ]]; then
        MAKE_FLAGS+=("info" "html")
    fi
fi

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=(install)
if [[ $(command -v asciidoc 2>/dev/null) ]]; then
    if [[ $(command -v makeinfo 2>/dev/null) ]]; then
        MAKE_FLAGS+=("install-man")
    fi
    if [[ $(command -v xmlto 2>/dev/null) ]]; then
        MAKE_FLAGS+=("install-info" "install-html")
    fi
fi

# Git builds things during install, and they end up root:root.
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWWORD" | sudo -S chmod -R 0777 *
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo
echo "********** Cleanup **********"
echo

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR" "$UNISTR_TAR" "$UNISTR_DIR" "$TERMCAP_TAR"
            "$TERMCAP_DIR" "$READLN_TAR" "$READLN_DIR" "$PCRE_TAR" "$PCRE_DIR"
            "$PCRE2_TAR" "$PCRE2_DIR" "$ZLIB_TAR" "$ZLIB_DIR" "$BZ2_TAR" "$BZ2_DIR"
            "$IDN_TAR" "$IDN_DIR" "$ICONV_TAR" "$ICONV_DIR" "$CURL_TAR" "$CURL_DIR"
            "$GIT_TAR" "$GIT_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-git.sh 2>&1 | tee build-git.log
    if [[ -e build-git.log ]]; then
        rm build-git.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
