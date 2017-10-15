#!/usr/bin/env bash

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11

NCURSES_TAR=ncurses-6.0.tar.gz
NCURSES_DIR=ncurses-6.0

EMACS_TAR=emacs-24.5.tar.gz
EMACS_DIR=emacs-24.5

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

#if [[ -z $(which autoreconf) ]]; then
    #echo "Some packages require autoreconf. Please install autoconf or automake."
    #[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "Wget requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/identrust-root-x3.pem" ]]; then
    echo "Wget requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

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

if [[ ("$IS_FREEBSD" -eq "1" || "$IS_OPENBSD" -eq "1" || "$IS_NETBSD" -eq "1" || "$IS_DRAGONFLY" -eq "1" || "$IS_SOLARIS" -eq "1") ]]; then
    if [[ ! (-z $(which gmake 2>/dev/null | grep -v 'no gmake') ) ]]; then
        MAKE="gmake"
    else
        MAKE="make"
    fi
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

if [[ -z "$CC" ]]; then CC=$(which cc 2>/dev/null); fi
if [[ -z "$CC" ]]; then CC=gcc; fi

MARCH_ERROR=$($CC $SH_MARCH -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$MARCH_ERROR" -ne "0" ]]; then
	SH_MARCH=
fi

# Solaris fixup.... Ncurses 6.0 does not build and the patches don't apply
if [[ "$IS_SOLARIS" -ne "0" ]]; then
  NCURSES_TAR=ncurses-5.9.tar.gz
  NCURSES_DIR=ncurses-5.9
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
tar -xzf "$ZLIB_TAR"
cd "$ZLIB_DIR"

SH_LDLIBS=("-ldl -lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
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
echo "********** ncurses **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR" -O "$NCURSES_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
tar -xzf "$NCURSES_TAR"
cd "$NCURSES_DIR"

SH_LDLIBS=("-ldl -lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
    ./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS")
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
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
echo "********** Emacs **********"
echo

wget --ca-certificate="$IDENTRUST_ROOT" "http://mirrors.syringanetworks.net/gnu/emacs/$EMACS_TAR" -O "$EMACS_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download SSH"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$EMACS_DIR" &>/dev/null
tar -xzf "$EMACS_TAR"
cd "$EMACS_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include -DNDEBUG" CFLAGS="$SH_MARCH" CXXFLAGS="$SH_MARCH" \
    LDFLAGS="${SH_LDFLAGS[*]}" LIBS="${SH_LDLIBS[*]}" \
    ./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
    --with-xml2 --without-x --without-sound --without-xpm \
    --without-jpeg --without-tiff --without-gif --without-png --without-rsvg \
    --without-imagemagick --without-xft --without-libotf --without-m17n-flt \
    --without-xaw3d --without-toolkit-scroll-bars --without-gpm --without-dbus \
    --without-gconf --without-gsettings --without-makeinfo \
    --without-compress-install

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure SSH"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j "$MAKE_JOBS" all)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to build SSH"
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

    ARTIFACTS=("$ZLIB_TAR" "$ZLIB_DIR" "$NCURSES_TAR" "$NCURSES_DIR" "$EMACS_TAR" "$EMACS_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-emacs.sh 2>&1 | tee build-emacs.log
    if [[ -e build-emacs.log ]]; then
        rm build-emacs.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
