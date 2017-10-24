#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Readline from sources. Ncurses should
# be built first. If it is built, then tinfo will be used.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

READLN_TAR=readline-7.0.tar.gz
READLN_DIR=readline-7.0

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

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
    echo "PCRE requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)
IS_FEDORA=$(lsb_release -a 2>&1 | grep -i -c fedora)

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

if [[ "$IS_SOLARIS" -ne "0" ]]; then
    SH_MARCH="-m64"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
elif [[ "$IS_64BIT" -ne "0" ]]; then
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

# For the benefit of Readline. Make it run fast.
SH_NATIVE="-march=native"
NATIVE_ERROR=$($CC $SH_NATIVE -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    SH_NATIVE=
fi

GNU_LD=$(ld -v 2>&1 | grep -i -c 'GNU ld')
if [[ "$GNU_LD" -ne "0" ]]; then
    SH_ERROR=$(echo 'int main() {}' | $CC -Wl,--enable-new-dtags -x c -o /dev/null - 2>&1 | grep -i -c -E 'fatal|error|not found')
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_DTAGS="-Wl,--enable-new-dtags"
    fi
fi

###############################################################################

OPT_PKGCONFIG=("$INSTALL_LIBDIR/pkgconfig")
OPT_CPPFLAGS=("-I$INSTALL_PREFIX/include" "-DNDEBUG")
OPT_CFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_CXXFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
OPT_LIBS=("-ldl" "-lpthread")

if [[ ! -z "$SH_PIC" ]]; then
    OPT_CFLAGS+=("$SH_PIC")
    OPT_CXXFLAGS+=("$SH_PIC")
fi

if [[ ! -z "$SH_DTAGS" ]]; then
    OPT_LDFLAGS+=("$SH_DTAGS")
fi

###############################################################################

# If IS_EXPORTED=1, then it was set in the parent shell
IS_EXPORTED=$(export | grep -c SUDO_PASSWORD)
if [[ "$IS_EXPORTED" -eq "0" ]]; then

  echo
  echo "If you enter a sudo password, then it will be used for installation."
  echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
  echo "To avoid sudo and the password, just press ENTER and they won't be used."
  read -r -s -p "Please enter password for sudo: " SUDO_PASSWORD
  echo

  # If IS_EXPORTED=2, then we unset it after we are done
  export SUDO_PASSWORD
  IS_EXPORTED=2
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

    PKG_CONFIG_PATH="${OPT_PKGCONFIG[*]}" \
    CPPFLAGS="${OPT_CPPFLAGS[*]}" \
    CFLAGS="${OPT_CFLAGS[*]}" CXXFLAGS="${OPT_CXXFLAGS[*]}" \
    LDFLAGS="${OPT_LDFLAGS[*]}" LIBS="${OPT_LIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --enable-shared --with-curses

# Fix broken Linux dynamic linker. tinfow or tinfo from ncurses
if [[ ! -z $(find /usr/local/lib64 -name '*tinfow*') ]]; then
    SH_TINFO="-ltinfow"
elif [[ ! -z $(find /usr/local/lib64 -name '*tinfo*') ]]; then
    SH_TINFO="-ltinfo"
fi

if [[ ! -z "$SH_TINFO" ]]; then
    for mfile in $(find "$PWD" -name 'Makefile'); do
        sed -i "s|SHLIB_LIBS =|SHLIB_LIBS = $SH_TINFO|g" "$mfile"
    done
fi

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S rm -f "$INSTALL_LIBDIR/libreadline*.*"
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    rm -rf "$INSTALL_LIBDIR/libreadline*.*"
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$READLN_TAR" "$READLN_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-readline.sh 2>&1 | tee build-readline.log
    if [[ -e build-readline.log ]]; then
        rm -f build-readline.log
    fi
fi

# If IS_EXPORTED=2, then we set it
if [[ "$IS_EXPORTED" -eq "2" ]]; then
    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
