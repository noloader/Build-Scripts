#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Emacs and its dependencies from sources.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

EMACS_TAR=emacs-24.5.tar.gz
EMACS_DIR=emacs-24.5

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
    echo "Emacs requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/identrust-root-x3.pem" ]]; then
    echo "Emacs requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c cygwin)
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

# For the benefit of Emacs. Make it run fast.
SH_NATIVE="-march=native"
NATIVE_ERROR=$($CC $SH_NATIVE -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    SH_NATIVE=
fi

SH_DTAGS="-Wl,--enable-new-dtags"
DT_ERROR=$($CC $SH_DTAGS -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$DT_ERROR" -ne "0" ]]; then
    SH_DTAGS=
fi

###############################################################################

OPT_PKGCONFIG=("$INSTALL_LIBDIR/pkgconfig")
OPT_CPPFLAGS=("-I$INSTALL_PREFIX/include" "-DNDEBUG")
OPT_CFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_CXXFLAGS=("$SH_MARCH" "$SH_NATIVE")
OPT_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
OPT_LIBS=("-ldl" "-lpthread")

# http://pubs.opengroup.org/onlinepubs/009695399/functions/xsh_chap02_02.html
# But Cygwin or Newlib headers are mostly fucked up at the moment.
if [[ "$IS_NEWLIB" -ne "0" ]] || [[ "$IS_CYGWIN" -ne "0" ]]; then
    OPT_CPPFLAGS+=("-D_XOPEN_SOURCE=600")
fi

if [[ ! -z "$SH_DTAGS" ]]; then
    OPT_LDFLAGS+=("$SH_DTAGS")
fi

echo ""
echo "Common flags and options:"
echo "  PKGCONFIG: ${OPT_PKGCONFIG[*]}"
echo "   CPPFLAGS: ${OPT_CPPFLAGS[*]}"
echo "     CFLAGS: ${OPT_CFLAGS[*]}"
echo "   CXXFLAGS: ${OPT_CXXFLAGS[*]}"
echo "    LDFLAGS: ${OPT_LDFLAGS[*]}"
echo "     LDLIBS: ${OPT_LIBS[*]}"

###############################################################################

IS_EXPORTED=$(export | grep -c SUDO_PASSWWORD)
if [[ "$IS_EXPORTED" -eq "0" ]]; then

  echo
  echo "If you enter a sudo password, then it will be used for installation."
  echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
  echo "To avoid sudo and the password, just press ENTER and they won't be used."
  read -r -s -p "Please enter password for sudo: " SUDO_PASSWWORD
  echo

  # If IS_EXPORTED=2, then we unset it after we are done
  export SUDO_PASSWWORD
  IS_EXPORTED=2
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Emacs **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/gnu/emacs/$EMACS_TAR" -O "$EMACS_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Emacs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$EMACS_DIR" &>/dev/null
gzip -d < "$EMACS_TAR" | tar xf -
cd "$EMACS_DIR"

    PKG_CONFIG_PATH="${OPT_PKGCONFIG[*]}" \
    CPPFLAGS="${OPT_CPPFLAGS[*]}" \
    CFLAGS="${OPT_CFLAGS[*]}" CXXFLAGS="${OPT_CXXFLAGS[*]}" \
    LDFLAGS="${OPT_LDFLAGS[*]}" LIBS="${OPT_LIBS[*]}" \
./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --with-xml2 --without-x --without-sound --without-xpm \
    --without-jpeg --without-tiff --without-gif --without-png --without-rsvg \
    --without-imagemagick --without-xft --without-libotf --without-m17n-flt \
    --without-xaw3d --without-toolkit-scroll-bars --without-gpm --without-dbus \
    --without-gconf --without-gsettings --without-makeinfo \
    --without-compress-install

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure emacs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build emacs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$NCURSES_TAR" "$NCURSES_DIR" "$EMACS_TAR" "$EMACS_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-emacs.sh 2>&1 | tee build-emacs.log
    if [[ -e build-emacs.log ]]; then
        rm build-emacs.log
    fi
fi

# If IS_EXPORTED=2, then we set it
if [[ "$IS_EXPORTED" -eq "2" ]]; then
    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
