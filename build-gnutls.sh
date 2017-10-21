#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11

NETTLE_TAR=nettle-3.3.tar.gz
NETTLE_DIR=nettle-3.3

GMP_TAR=gmp-6.1.2.tar.bz2
GMP_DIR=gmp-6.1.2

ICONV_TAR=libiconv-1.15.tar.gz
ICONV_DIR=libiconv-1.15

EXPAT_TAR=R_2_2_4.tar.gz
EXPAT_DIR=libexpat-R_2_2_4

UNBOUND_TAR=unbound-1.6.7.tar.gz
UNBOUND_DIR=unbound-1.6.7

GUILE_TAR=guile-2.2.2.tar.xz
GUILE_DIR=guile-2.2.2

TASN1_TAR=libtasn1-4.12.tar.gz
TASN1_DIR=libtasn1-4.12

# Ncurses 6.0 fails to compile on Solaris 11 and Ubuntu 17
NCURSES_TAR=ncurses-6.0.tar.gz
NCURSES_DIR=ncurses-6.0

P11GLUE_TAR=p11-kit-0.23.2.tar.gz
P11GLUE_DIR=p11-kit-0.23.2

GNUTLS_TAR=gnutls-3.5.15.tar.xz
GNUTLS_DIR=gnutls-3.5.15

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs
MAKE_JOBS=4

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
    echo "Some packages gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v bzip2 2>/dev/null) ]]; then
    echo "Some packages bzip2. Please install bzip2."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

IS_DARWIN=$(uname -s | grep -i -c darwin)
if [[ ("$IS_DARWIN" -eq "0") ]] && [[ -z $(command -v libtoolize 2>/dev/null) ]]; then
    echo "Some packages require libtool. Please install libtool or libtool-bin."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "GnuTLS requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/identrust-root-x3.pem" ]]; then
    echo "GnuTLS requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/digicert-root-ca.pem" ]]; then
    echo "GnuTLS requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"
DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"
ADDTRUST_ROOT="$HOME/.cacert/addtrust-root-ca.pem"

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
IS_FEDORA=$(lsb_release -a 2>/dev/null | grep -i -c 'Fedora')

# The BSDs and Solaris should have GMake installed if its needed
if [[ $(command -v gmake 2>/dev/null) ]]; then
    MAKE="gmake"
else
    MAKE="make"
fi

# Boehm garbage collector. Look in /usr/lib and /usr/lib64
if [[ "$IS_DEBIAN" -ne "0" ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "GnuTLS requires Boehm garbage collector. Please install libgc-dev."
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
elif [[ "$IS_FEDORA" -ne "0" ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "GnuTLS requires Boehm garbage collector. Please install gc-devel."
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -eq "1" ]]; then
    SH_MARCH="-m64"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
elif [[ "$IS_64BIT" -eq "1" ]]; then
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    else
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    fi
else
    SH_MARCH="-m32"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
fi

if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi

MARCH_ERROR=$($CC $SH_MARCH -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$MARCH_ERROR" -ne "0" ]]; then
    SH_MARCH=
fi

SH_PIC="-fPIC"
PIC_ERROR=$($CC $SH_PIC -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$PIC_ERROR" -ne "0" ]]; then
    SH_PIC=
fi

# For the benefit of Nettle and GMP. Make it run fast.
SH_NATIVE="-march=native"
NATIVE_ERROR=$($CC $SH_NATIVE -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    SH_NATIVE=
fi

# Solaris fixup.... Ncurses 6.0 does not build and the patches don't apply
if [[ "$IS_SOLARIS" -ne "0" ]]; then
  NCURSES_TAR=ncurses-5.9.tar.gz
  NCURSES_DIR=ncurses-5.9
fi

###############################################################################

echo
echo "If you enter a sudo password, then it will be used for installation."
echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
echo "To avoid sudo and the password, just press ENTER and they won't be used."
read -r -s -p "Please enter password for sudo: " SUDO_PASSWWORD
echo

###############################################################################

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

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

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
echo "********** libtasn1 **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/libtasn1/$TASN1_TAR" -O "$TASN1_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download libtasn1"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$TASN1_DIR" &>/dev/null
gzip -d < "$TASN1_TAR" | tar xf -
cd "$TASN1_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure libtasn1"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libtasn1"
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
echo "********** GMP **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/gmp/$GMP_TAR" -O "$GMP_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GMP_DIR" &>/dev/null
bzip2 -d < "$GMP_TAR" | tar xf -
cd "$GMP_DIR"

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GMP"
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
echo "********** Nettle **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/nettle/$NETTLE_TAR" -O "$NETTLE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NETTLE_DIR" &>/dev/null
gzip -d < "$NETTLE_TAR" | tar xf -
cd "$NETTLE_DIR"

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Nettle"
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

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

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
echo "********** libexpat **********"
echo

wget --ca-certificate="$DIGICERT_ROOT" "https://github.com/libexpat/libexpat/archive/$EXPAT_TAR" -O "$EXPAT_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download libexpat"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$EXPAT_DIR" &>/dev/null
gzip -d < "$EXPAT_TAR" | tar xf -
cd "$EXPAT_DIR/expat"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

if ! ./buildconf.sh
then
    echo "Failed to generate libexpat configure"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --without-xmlwf

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure libexpat"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libexpat"
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
echo "********** Unbound **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://unbound.net/downloads/$UNBOUND_TAR" -O "$UNBOUND_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Unbound"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$UNBOUND_DIR" &>/dev/null
gzip -d < "$UNBOUND_TAR" | tar xf -
cd "$UNBOUND_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Unbound"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Unbound"
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
echo "********** ncurses **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR" -O "$NCURSES_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG $SH_PIC" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build ncurses"
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
echo "********** Guile **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/guile/$GUILE_TAR" -O "$GUILE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GUILE_DIR" &>/dev/null
tar xJf "$GUILE_TAR"
cd "$GUILE_DIR"

# Rebuild libtool, http://stackoverflow.com/q/35589427/608639
autoconf

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --with-libgmp-prefix="$INSTALL_PREFIX" \
    --with-libunistring-prefix="$INSTALL_PREFIX" \
    --with-libiconv-prefix="$INSTALL_PREFIX"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Guile"
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
echo "********** p11-glue **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://p11-glue.freedesktop.org/releases/$P11GLUE_TAR" -O "$P11GLUE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download p11-glue"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$P11GLUE_DIR" &>/dev/null
gzip -d < "$P11GLUE_TAR" | tar xf -
cd "$P11GLUE_DIR"

 http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDLIBS=("-ldl" "-lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure p11-glue"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build p11-glue"
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
if [[ "$IS_LINUX" -ne "0" ]]; then
    sed -i -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure
fi

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

    PKG_CONFIG_PATH="$INSTALL_LIBDIR/pkgconfig" \
    CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" \
    CFLAGS="$SH_MARCH $SH_NATIVE" \
    CXXFLAGS="$SH_MARCH $SH_NATIVE" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --with-libz-prefix="$INSTALL_PREFIX" --with-libiconv-prefix="$INSTALL_PREFIX" \
    --with-libunbound="$INSTALL_PREFIX"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS" all)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GnuTLS"
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
echo "********** Cleanup **********"
echo

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$ZLIB_TAR" "$ZLIB_DIR" "$NETTLE_TAR" "$NETTLE_DIR" "$GMP_TAR" "$GMP_DIR"
               "$EXPAT_TAR" "$EXPAT_DIR" "$UNBOUND_TAR" "$UNBOUND_TAR" "$TASN1_TAR"
               "$NCURSES_TAR" "$NCURSES_DIR" "$GUILE_TAR" "$GUILE_TAR"
               "$TASN1_DIR" "$P11GLUE_TAR" "$P11GLUE_DIR" "$GNUTLS_TAR" "$GNUTLS_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnutls.sh 2>&1 | tee build-gnutls.log
    if [[ -e build-gnutls.log ]]; then
        rm build-gnutls.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
