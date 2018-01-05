#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script creates the environment for other scripts to execute in.

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

THIS_SYSTEM=$(uname -s 2>&1)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_AIX=$(echo -n "$THIS_SYSTEM" | grep -i -c 'aix')

# The BSDs and Solaris should have GMake installed if its needed
if [[ -z "$MAKE" ]]; then
    if [[ $(command -v gmake 2>/dev/null) ]]; then
        export MAKE="gmake"
    else
        export MAKE="make"
    fi
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

# Don't override a user choice of INSTALL_PREFIX
if [[ -z "$INSTALL_PREFIX" ]]; then
    INSTALL_PREFIX="/usr/local"
    export INSTALL_PREFIX
fi

# Don't override a user choice of INSTALL_LIBDIR
if [[ -z "$INSTALL_LIBDIR" ]]; then
    if [[ "$IS_SOLARIS" -ne "0" ]]; then
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    elif [[ "$IS_64BIT" -ne "0" ]]; then
        if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
            INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
            INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
        else
            INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
        fi
    else
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    fi

    export INSTALL_LIBDIR
fi

if [[ "$IS_SOLARIS" -ne "0" ]]; then
    SH_BITS=64
    SH_MARCH="64"
elif [[ "$IS_64BIT" -ne "0" ]]; then
    SH_BITS=64
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_MARCH="64"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_MARCH="64"
    else
        SH_MARCH="64"
    fi
else
    SH_BITS=32
    SH_MARCH="32"
fi

# If CC and CXX is not set, then use default or assume GCC
if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CC" && $(command -v gcc 2>/dev/null) ) ]]; then CC=$(command -v gcc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi
if [[ (-z "$CXX" && $(command -v g++ 2>/dev/null) ) ]]; then CXX=$(command -v g++); fi

# `gcc ... -o /dev/null` does not work on Solaris due to LD bug.
# `mktemp` is not available on AIX or Git Windows shell...
infile="in.$RANDOM$RANDOM.c"
outfile="out.$RANDOM$RANDOM"
echo 'int main(int argc, char* argv[]) {return 0;}' > "$infile"
echo "" >> "$infile"

BAD_MSG="fatal|error|unknown|unrecognized|not found|not exist"

# Try to determine -m64, -X64, -m32, -X32, etc
if [[ "$SH_MARCH" = "32" ]]; then
    SH_MARCH=
    MARCH_ERROR=$($CC -m32 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$MARCH_ERROR" -eq "0" ]]; then
        SH_MARCH="-m32"
    fi
    # IBM XL C/C++ on AIX uses -X32 and -X64
    MARCH_ERROR=$($CC -X32 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$MARCH_ERROR" -eq "0" ]] && [[ "$IS_AIX" -ne "0" ]]; then
        SH_MARCH="-X32"
    fi
fi
if [[ "$SH_MARCH" = "64" ]]; then
    SH_MARCH=
    MARCH_ERROR=$($CC -m64 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$MARCH_ERROR" -eq "0" ]]; then
        SH_MARCH="-m64"
    fi
    # IBM XL C/C++ on AIX uses -X32 and -X64
    MARCH_ERROR=$($CC -X64 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$MARCH_ERROR" -eq "0" ]] && [[ "$IS_AIX" -ne "0" ]]; then
        SH_MARCH="-X64"
    fi
fi

PIC_ERROR=$($CC -fPIC -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$PIC_ERROR" -eq "0" ]]; then
    SH_PIC="-fPIC"
fi

# For the benefit of the programs and libraries. Make them run faster.
NATIVE_ERROR=$($CC -march=native -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$NATIVE_ERROR" -eq "0" ]]; then
    SH_NATIVE="-march=native"
fi

RPATH_ERROR=$($CC -Wl,-rpath,$INSTALL_LIBDIR -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$RPATH_ERROR" -eq "0" ]]; then
    SH_RPATH="-Wl,-rpath,$INSTALL_LIBDIR"
fi

# AIX ld uses -R for runpath when -bsvr4
RPATH_ERROR=$($CC -Wl,-R,$INSTALL_LIBDIR -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$RPATH_ERROR" -eq "0" ]]; then
    SH_RPATH="-Wl,-R,$INSTALL_LIBDIR"
fi

SH_ERROR=$($CC -Wl,--enable-new-dtags -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$SH_ERROR" -eq "0" ]]; then
    SH_DTAGS="-Wl,--enable-new-dtags"
fi

# OS X linker and install names
SH_ERROR=$($CC -headerpad_max_install_names -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$SH_ERROR" -eq "0" ]]; then
    SH_INSTNAME="-headerpad_max_install_names"
fi

rm -f "$infile" 2>/dev/null
rm -f "$outfile" 2>/dev/null

###############################################################################

# CA cert path? Also see http://gagravarr.org/writing/openssl-certs/others.shtml
if [[ -e "/etc/ssl/certs/ca-certificates.crt" ]]; then
    SH_CACERT_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
elif [[ -e "/etc/ssl/certs/ca-bundle.crt" ]]; then
    SH_CACERT_BUNDLE="/etc/ssl/certs/ca-bundle.crt"
elif [[ -d "/etc/ssl/certs" ]]; then
    SH_CACERT_PATH="/etc/ssl/certs"
elif [[ -d "/etc/openssl/certs" ]]; then
    SH_CACERT_PATH="/etc/openssl/certs"
elif [[ -d "/etc/pki/tls/" ]]; then
    SH_CACERT_PATH="/etc/pki/tls/"
elif [[ -d "/etc/ssl/certs/" ]]; then
    SH_CACERT_PATH="/etc/ssl/certs/"
elif [[ -d "/etc/pki/ca-trust/extracted/pem/" ]]; then
    SH_CACERT_PATH="/etc/pki/ca-trust/extracted/pem/certs"
fi

###############################################################################

BUILD_PKGCONFIG=("$INSTALL_LIBDIR/pkgconfig")
BUILD_CPPFLAGS=("-I$INSTALL_PREFIX/include" "-DNDEBUG")
BUILD_CFLAGS=()
BUILD_CXXFLAGS=()
BUILD_LDFLAGS=("-L$INSTALL_LIBDIR")
BUILD_LIBS=("-ldl" "-lpthread")

if [[ ! -z "$SH_MARCH" ]]; then
    BUILD_CFLAGS+=("$SH_MARCH")
    BUILD_CXXFLAGS+=("$SH_MARCH")
    BUILD_LDFLAGS+=("$SH_MARCH")
fi

if [[ ! -z "$SH_NATIVE" ]]; then
    BUILD_CFLAGS+=("$SH_NATIVE")
    BUILD_CXXFLAGS+=("$SH_NATIVE")
fi

if [[ ! -z "$SH_PIC" ]]; then
    BUILD_CFLAGS+=("$SH_PIC")
    BUILD_CXXFLAGS+=("$SH_PIC")
fi

if [[ ! -z "$SH_RPATH" ]]; then
    BUILD_LDFLAGS+=("$SH_RPATH")
fi

if [[ ! -z "$SH_DTAGS" ]]; then
    BUILD_LDFLAGS+=("$SH_DTAGS")
fi

#if [[ "$IS_DARWIN" -ne "0" ]] && [[ ! -z "$SH_INSTNAME" ]]; then
#    BUILD_LDFLAGS+=("$SH_INSTNAME")
#fi

if [[ -z "$BUILD_OPTS" ]]; then

    echo ""
    echo "Common flags and options:"
    echo ""
    echo " INSTALL_PREFIX: $INSTALL_PREFIX"
    echo " INSTALL_LIBDIR: $INSTALL_LIBDIR"
    echo ""
    echo "      PKGCONFIG: ${BUILD_PKGCONFIG[*]}"
    echo "       CPPFLAGS: ${BUILD_CPPFLAGS[*]}"
    echo "         CFLAGS: ${BUILD_CFLAGS[*]}"
    echo "       CXXFLAGS: ${BUILD_CXXFLAGS[*]}"
    echo "        LDFLAGS: ${BUILD_LDFLAGS[*]}"
    echo "         LDLIBS: ${BUILD_LIBS[*]}"

    if [[ ! -z "$SH_CACERT_PATH" ]]; then
        echo ""
        echo " SH_CACERT_PATH: $SH_CACERT_PATH"
    fi
    if [[ ! -z "$SH_CACERT_BUNDLE" ]]; then
        echo ""
        echo " SH_CACERT_BUNDLE: $SH_CACERT_BUNDLE"
    fi
fi

export BUILD_OPTS="TRUE"