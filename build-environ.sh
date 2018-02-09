#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script verifies most prerequisites and creates
# an environment for other scripts to execute in.

###############################################################################

# Prerequisites needed for nearly all packages

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"

if [[ ! -f "$IDENTRUST_ROOT" ]]; then
    echo "Some packages require several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require Autotools. Please install autoconf, automake and libtool."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

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
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c 'sunos')
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c 'darwin')
IS_AIX=$(echo -n "$THIS_SYSTEM" | grep -i -c 'aix')
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c 'cygwin')
IS_OPENBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c 'openbsd')

THIS_MACHINE=$(uname -m 2>&1)
IS_IA32=$(echo -n "$THIS_MACHINE" | grep -E -i -c 'i.86|amd64|x86_64')
IS_X86_64=$(echo -n "$THIS_MACHINE" | grep -E -i -c 'amd64|x86_64')

# The BSDs and Solaris should have GMake installed if its needed
if [[ -z "$MAKE" ]]; then
    if [[ $(command -v gmake 2>/dev/null) ]]; then
        MAKE="gmake"
    else
        MAKE="make"
    fi
fi

# Needed for OpenSSL and make jobs
IS_GMAKE=$($MAKE -v 2>&1 | grep -i -c 'gnu make')

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

# Don't override a user choice of INSTX_PREFIX
if [[ -z "$INSTX_PREFIX" ]]; then
    INSTX_PREFIX="/usr/local"
fi

# Don't override a user choice of INSTX_LIBDIR
if [[ -z "$INSTX_LIBDIR" ]]; then
    if [[ "$IS_SOLARIS" -ne "0" ]]; then
        INSTX_LIBDIR="$INSTX_PREFIX/lib64"
    elif [[ "$IS_64BIT" -ne "0" ]]; then
        if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
            INSTX_LIBDIR="$INSTX_PREFIX/lib"
        elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
            INSTX_LIBDIR="$INSTX_PREFIX/lib64"
        else
            INSTX_LIBDIR="$INSTX_PREFIX/lib"
        fi
    else
        INSTX_LIBDIR="$INSTX_PREFIX/lib"
    fi
fi

if [[ "$IS_SOLARIS" -ne "0" ]]; then
    BUILD_BITS=64
    SH_MARCH="64"
elif [[ "$IS_64BIT" -ne "0" ]]; then
    BUILD_BITS=64
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_MARCH="64"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_MARCH="64"
    else
        SH_MARCH="64"
    fi
else
    BUILD_BITS=32
    SH_MARCH="32"
fi

# If CC and CXX is not set, then use default or assume GCC
if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CC" && $(command -v gcc 2>/dev/null) ) ]]; then CC=$(command -v gcc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi
if [[ (-z "$CXX" && $(command -v g++ 2>/dev/null) ) ]]; then CXX=$(command -v g++); fi

IS_GCC=$("$CC" --version 2>&1 | grep -i -c -E 'gcc')
IS_CLANG=$("$CC" --version 2>&1 | grep -i -c -E 'clang|llvm')

# `gcc ... -o /dev/null` does not work on Solaris due to LD bug.
# `mktemp` is not available on AIX or Git Windows shell...
infile="in.$RANDOM$RANDOM.c"
outfile="out.$RANDOM$RANDOM"
echo 'int main(int argc, char* argv[]) {return 0;}' > "$infile"
echo "" >> "$infile"

BAD_MSG="fatal|error|unknown|unrecognized|not found|not exist|cannot find"

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

RPATH_ERROR=$($CC -Wl,-rpath,$INSTX_LIBDIR -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$RPATH_ERROR" -eq "0" ]]; then
    SH_RPATH="-Wl,-rpath,$INSTX_LIBDIR"
fi

# AIX ld uses -R for runpath when -bsvr4
RPATH_ERROR=$($CC -Wl,-R,$INSTX_LIBDIR -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$RPATH_ERROR" -eq "0" ]]; then
    SH_RPATH="-Wl,-R,$INSTX_LIBDIR"
fi

OPENMP_ERROR=$($CC -fopenmp -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
if [[ "$SH_ERROR" -eq "0" ]]; then
    SH_OPENMP="-fopenmp"
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

# Debug symbols
if [[ -z "$SH_SYM" ]]; then
    SH_ERROR=$($CC -g2 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_SYM="-g2"
    else
        SH_SYM="-g"
    fi
fi

# Optimizations symbols
if [[ -z "$SH_OPT" ]]; then
    SH_ERROR=$($CC -O2 -o "$outfile" "$infile" 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_OPT="-O2"
    else
        SH_OPT="-O"
    fi
fi

# OpenBSD does not have -ldl
if [[ -z "$SH_DL" ]]; then
    SH_ERROR=$($CC -o "$outfile" "$infile" -ldl 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_DL="-ldl"
    fi
fi

if [[ -z "$SH_PTHREAD" ]]; then
    SH_ERROR=$($CC -o "$outfile" "$infile" -lpthread 2>&1 | grep -i -c -E "$BAD_MSG")
    if [[ "$SH_ERROR" -eq "0" ]]; then
        SH_PTHREAD="-lpthread"
    fi
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

BUILD_PKGCONFIG=("$INSTX_LIBDIR/pkgconfig")
BUILD_CPPFLAGS=("-I$INSTX_PREFIX/include" "-DNDEBUG")
BUILD_CFLAGS=("$SH_SYM" "$SH_OPT")
BUILD_CXXFLAGS=("$SH_SYM" "$SH_OPT")
BUILD_LDFLAGS=("-L$INSTX_LIBDIR")
BUILD_LIBS=()

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

if [[ ! -z "$SH_DL" ]]; then
    BUILD_LIBS+=("-ldl")
fi

if [[ ! -z "$SH_PTHREAD" ]]; then
    BUILD_LIBS+=("-lpthread")
fi

#if [[ "$IS_DARWIN" -ne "0" ]] && [[ ! -z "$SH_INSTNAME" ]]; then
#    BUILD_LDFLAGS+=("$SH_INSTNAME")
#fi

# Used to track packages that have been built by these scripts.
# The accounting is local to a user account. There is no harm
# in rebuilding a package under another account.
if [[ -z "$INSTX_CACHE" ]]; then
    INSTX_CACHE="$HOME/.build-scripts"
fi
mkdir -p "$INSTX_CACHE"

###############################################################################

# If the package is older than 7 days, then rebuild it. This sidesteps the
# problem of continually rebuilding the same package when installing a
# program like Git and SSH. It also avoids version tracking by automatically
# building a package after 7 days (even if it is the same version).
for pkg in $(find "$INSTX_CACHE" -type f -mtime +7 2>/dev/null);
do
    # echo "Setting $pkg for rebuild"
    rm -f "$pkg" 2>/dev/null
done

###############################################################################

# Print a summary once
if [[ -z "$PRINT_ONCE" ]]; then

    echo ""
    echo "Common flags and options:"
    echo ""
    echo " INSTX_PREFIX: $INSTX_PREFIX"
    echo " INSTX_LIBDIR: $INSTX_LIBDIR"
    echo ""
    echo "    PKGCONFIG: ${BUILD_PKGCONFIG[*]}"
    echo "     CPPFLAGS: ${BUILD_CPPFLAGS[*]}"
    echo "       CFLAGS: ${BUILD_CFLAGS[*]}"
    echo "     CXXFLAGS: ${BUILD_CXXFLAGS[*]}"
    echo "      LDFLAGS: ${BUILD_LDFLAGS[*]}"
    echo "       LDLIBS: ${BUILD_LIBS[*]}"

    if [[ ! -z "$SH_CACERT_PATH" ]]; then
        echo ""
        echo " SH_CACERT_PATH: $SH_CACERT_PATH"
    fi
    if [[ ! -z "$SH_CACERT_BUNDLE" ]]; then
        echo ""
        echo " SH_CACERT_BUNDLE: $SH_CACERT_BUNDLE"
    fi

    export PRINT_ONCE="TRUE"
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
