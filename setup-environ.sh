#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script verifies most prerequisites and creates
# an environment for other scripts to execute in.
#
# Generally speaking, a variable with uppercase INSTX_ is used
# throughout the scripts, like INSTX_CFLAGS and INSTX_CXX11. The
# INSTX_ variables are usually exported. A variable with lowercase
# opt_ is used only in this file. The opt_variables stay local to
# this file.
#
# We use Bash arrays, but we avoid ARR+=("$foo"). The '+=' operator
# came after arrays in Bash history. Early machines will handle arrays
# but not the '+=' operator.
#
# The 'grep' command is Posix, and the options -i, -c, and -E are Posix.
# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html
#
# The 'command' command is Posix, and the option -v is Posix.
# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/command.html
#
# The 'awk' command is Posix, and printing fields using NR is Posix.
# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html

###############################################################################

# SC2034: XXX appears unused. Verify use (or export if used externally).
# SC2086: Double quote to prevent globbing and word splitting.
# shellcheck disable=SC2034,SC2086

###############################################################################

# `gcc ... -o /dev/null` does not work on Solaris.
# `mktemp` is not available on AIX or Git Windows shell...
infile="in.$RANDOM$RANDOM.c"
outfile="out.$RANDOM$RANDOM"
cp programs/test-stdc.c "$infile"

###############################################################################

CURR_DIR=$(pwd); export CURR_DIR
function finish {
  rm  -f "$CURR_DIR/$infile" 2>/dev/null
  rm  -f "$CURR_DIR/$outfile" 2>/dev/null
  rm -rf "$CURR_DIR/$outfile.dSYM" 2>/dev/null
}
trap finish EXIT INT

###############################################################################

# Prerequisites needed for nearly all packages. Set to 1 to skip check.

if [[ "$INSTX_DISABLE_PKGCONFIG_CHECK" -ne 1 ]]; then
    if [[ -z $(command -v pkg-config 2>/dev/null) ]]; then
        printf "%s\n" "Some packages require Package-config. Please install pkg-config, pkgconfig or pkgconf."
        [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

if [[ "$INSTX_DISABLE_GZIP_CHECK" -ne 1 ]]; then
    if [[ -z $(command -v gzip 2>/dev/null) ]]; then
        printf "%s\n" "Some packages require Gzip. Please install Gzip."
        [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

if [[ "$INSTX_DISABLE_TAR_CHECK" -ne 1 ]]; then
    if [[ -z $(command -v tar 2>/dev/null) ]]; then
        printf "%s\n" "Some packages require Tar. Please install Tar."
        [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

###############################################################################

# Command line tools, like sed and awk, need this on OS X.
if [[ $(uname -s | grep -i -c 'darwin') -ne 0 ]]; then
    if [[ -z "$LC_ALL" ]]; then
        if locale -a 2>/dev/null | grep -q en_US.UTF-8; then
            export LC_ALL="en_US.UTF-8"
        elif locale -a 2>/dev/null | grep -q '^C'; then
            export LC_ALL="C"
        fi
    fi
    if [[ -z "$LANG" ]]; then
        if locale -a 2>/dev/null | grep -q en_US.UTF-8; then
            export LANG="en_US.UTF-8"
        elif locale -a 2>/dev/null | grep -q '^C'; then
            export LANG="C"
        fi
    fi
fi

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_HURD=$(grep -i -c 'gnu' <<< "$THIS_SYSTEM")
IS_LINUX=$(grep -i -c 'linux' <<< "$THIS_SYSTEM")
IS_SOLARIS=$(grep -i -c 'sunos' <<< "$THIS_SYSTEM")
IS_DARWIN=$(grep -i -c 'darwin' <<< "$THIS_SYSTEM")
IS_AIX=$(grep -i -c 'aix' <<< "$THIS_SYSTEM")
IS_CYGWIN=$(grep -i -c 'cygwin' <<< "$THIS_SYSTEM")
IS_OPENBSD=$(grep -i -c 'openbsd' <<< "$THIS_SYSTEM")
IS_FREEBSD=$(grep -i -c 'freebsd' <<< "$THIS_SYSTEM")
IS_NETBSD=$(grep -i -c 'netbsd' <<< "$THIS_SYSTEM")

THIS_SYSTEM=$(uname -v 2>&1)
IS_ALPINE=$(grep -i -c 'alpine' <<< "$THIS_SYSTEM")

export IS_LINUX IS_SOLARIS IS_DARWIN
export IS_CYGWIN IS_OPENBSD IS_FREEBSD IS_NETBSD
export IS_AIX IS_HURD IS_ALPINE

###############################################################################

GREP="${GREP:-"$(command -v grep 2>/dev/null)"}"
EGREP="${EGREP:-"$(command -v grep 2>/dev/null) -E"}"
SED="${SED:-"$(command -v sed  2>/dev/null)"}"
AWK="${AWK:-"$(command -v awk  2>/dev/null)"}"

# Non-anemic tools on Solaris
if [[ -d /usr/gnu/bin ]]; then
    GREP="/usr/gnu/bin/grep"
    EGREP="/usr/gnu/bin/grep -E"
    SED="/usr/gnu/bin/sed"
    AWK="/usr/gnu/bin/awk"
elif [[ -d /usr/sfw/bin ]]; then
    GREP="/usr/sfw/bin/grep"
    EGREP="/usr/sfw/bin/grep -E"
    SED="/usr/sfw/bin/sed"
    AWK="/usr/sfw/bin/awk"
fi

# Wget is special. We have to be able to bootstrap it and
# use a modern version throughout these scripts. The Wget
# we provide in $HOME is modern but crippled. However, it
# is enough to download all the packages we need.

if [[ -z "$WGET" ]]; then
    if [[ -e "$HOME/.build-scripts/wget/bin/wget" ]]; then
        WGET="$HOME/.build-scripts/wget/bin/wget"
    elif [[ -n "$(command -v wget 2>/dev/null)" ]]; then
        WGET="$(command -v wget 2>/dev/null)"
    fi
fi

# Automatically update the user's cacerts now. On occasion we need
# to add or remove a certificate. Otherwise, there are unexplained
# download failures.
bash setup-cacerts.sh 1>/dev/null

# OS X may not have a Wget available. However, a few build scripts
# intelligently fallback to cURL on OS X to get a critical download.
if [[ "$INSTX_DISABLE_WGET_CHECK" -ne 1 && -z "$WGET" ]]; then
    echo "Failed to find Wget. If you have one, set WGET=/path/to/wget."
    echo "If you don't have one, you can run ./setup-wget."
    exit 1
fi

export WGET

###############################################################################

# Paths are awful on Solaris. An unmodified environment only
# has /usr/bin and /usr/sbin on-path with anemic tools. They
# manage to provide fewer options than Posix...
if [ "$IS_SOLARIS" -ne 0 ]
then
    for path in /usr/gnu/bin /usr/sfw/bin /usr/ucb/bin /usr/xpg4/bin /bin /usr/bin /sbin /usr/sbin
    do
        if [ -d "$path" ]; then
            SOLARIS_PATH="$SOLARIS_PATH:$path"
        fi
    done

    # Add user's path in case a binary is in a non-standard location,
    # like /opt/local. Place the PATH after SOLARIS_PATH so the anemic
    # tools are last in the list.
    PATH="$SOLARIS_PATH:$PATH"
fi

# Strip duplicate, leading and trailing colons
PATH=$(echo "$PATH" | tr -s ':' | ${SED} -e 's/^:\(.*\)/\1/' | ${SED} -e 's/:$//g')
export PATH

# echo "New PATH: $PATH"

###############################################################################

# OS X flavors
OSX_VERSION=$(system_profiler SPSoftwareDataType 2>&1 | ${GREP} 'System Version:' | ${AWK} '{print $6}')
OSX_10p10_OR_ABOVE=$(${EGREP} -i -c -E "^10.10|^1[1-9].|^[2-9][0-9]" <<< "$OSX_VERSION")
OSX_10p5_OR_BELOW=$(${EGREP} -i -c -E "10\.[0-5]" <<< "$OSX_VERSION")

export OSX_10p5_OR_BELOW OSX_10p10_OR_ABOVE

# Check for the BSD family members
THIS_SYSTEM=$(uname -s 2>&1)
IS_BSD_FAMILY=$(${EGREP} -i -c 'dragonfly|freebsd|netbsd|openbsd' <<< "$THIS_SYSTEM")

# Red Hat and derivatives use /lib64, not /lib.
IS_REDHAT=$(${GREP} -i -c 'redhat' /etc/redhat-release 2>/dev/null)
IS_CENTOS=$(${GREP} -i -c 'centos' /etc/centos-release 2>/dev/null)
IS_FEDORA=$(${GREP} -i -c 'fedora' /etc/fedora-release 2>/dev/null)
IS_DRAGONFLY=$(uname -s | ${GREP} -i -c DragonFly 2>/dev/null)

if [[ "$IS_REDHAT" -ne 0 || "$IS_CENTOS" -ne 0 || "$IS_FEDORA" -ne 0 ]]
then
    IS_RH_FAMILY=1
else
    IS_RH_FAMILY=0
fi

THIS_MACHINE=$(uname -m 2>&1)
IS_IA32=$(${EGREP} -i -c 'i86pc|i.86|amd64|x86_64' <<< "$THIS_MACHINE")
IS_AMD64=$(${EGREP} -i -c 'amd64|x86_64' <<< "$THIS_MACHINE")
IS_MIPS=$(${EGREP} -i -c 'mips' <<< "$THIS_MACHINE")

export IS_IA32 IS_AMD64 IS_MIPS

# The BSDs and Solaris should have GMake installed if its needed
if [[ -z "${MAKE}" ]]; then
    if [[ $(command -v gmake 2>/dev/null) ]]; then
        MAKE="gmake"
    else
        MAKE="make"
    fi
fi

# Fix "don't know how to make w" on the BSDs
if [[ "${MAKE}" == "make" ]]; then
    MAKEOPTS=
fi

export MAKE MAKEOPTS

# If CC and CXX are not set, then use default or assume Clang or GCC
if [[ -z "${CC}" ]]; then
    CC=$(make -p 2>/dev/null | ${EGREP} '^CC.*=' | head -n 1 | cut -f 2 -d '=' | awk '{$1=$1};1')
fi
if [[ -z "${CXX}" ]]; then
    CXX=$(make -p 2>/dev/null | ${EGREP} '^CXX.*=' | head -n 1 | cut -f 2 -d '=' | awk '{$1=$1};1')
fi

# Fixup for Solaris
if [[ -z "$(command -v "${CC}" 2>/dev/null)" ]]; then CC= ; fi;
if [[ -z "$(command -v "${CXX}" 2>/dev/null)" ]]; then CXX= ; fi;

# Use Clang as default on Darwin
if [[ "$IS_DARWIN" -ne 0 ]]; then
    if [[ -z "${CC}" ]] && [[ -n "$(command -v clang 2>/dev/null)" ]]; then CC='clang'; fi
    if [[ -z "${CXX}" ]] && [[ -n "$(command -v clang++ 2>/dev/null)" ]]; then CXX='clang++'; fi
fi

# Use GCC as default elsewhere, or on Darwin if Clang fails
if [[ -z "${CC}" ]] && [[ -n "$(command -v gcc 2>/dev/null)" ]]; then CC='gcc'; fi
if [[ -z "${CXX}" ]] && [[ -n "$(command -v g++ 2>/dev/null)" ]]; then CXX='g++'; fi

# Finally, use the full path
CC="$(command -v "${CC}" 2>/dev/null)"
CXX="$(command -v "${CXX}" 2>/dev/null)"

TEST_CC="${CC}"
TEST_CXX="${CXX}"

export CC CXX

IS_GCC=$(${CC} --version 2>&1 | ${EGREP} -i -c 'gnu|gcc')
IS_CLANG=$(${CC} --version 2>&1 | ${EGREP} -i -c 'clang|llvm')
IS_SUNC=$(${CC} -V 2>&1 | ${EGREP} -i -c 'sun|studio')

###############################################################################

# Where the package will run. We need to override for 64-bit Solaris.
# On Solaris some Autotools packages use 32-bit instead of 64-bit build.
AUTOCONF_BUILD=$(bash programs/config.guess 2>/dev/null)

# Use 64-bit for Solaris if available
# https://docs.oracle.com/cd/E37838_01/html/E66175/features-1.html

if [[ "$IS_SOLARIS" -ne 0 ]]
then
    if [[ $(isainfo -b 2>/dev/null) = 64 ]]; then
        CFLAGS64=-m64
        CXXFLAGS64=-m64
        TEST_CC="${TEST_CC} -m64"
        TEST_CXX="${TEST_CXX} -m64"
    fi
fi

IS_SUN_AMD64=$(isainfo -v 2>/dev/null | ${EGREP} -i -c 'amd64')
IS_SUN_SPARCv9=$(isainfo -v 2>/dev/null | ${EGREP} -i -c 'sparcv9')

# Solaris Fixup
if [[ "$IS_SUN_AMD64" -eq 1 ]]; then
    IS_AMD64=1
    AUTOCONF_BUILD=$(${SED} 's/i386/x86_64/g' <<< "${AUTOCONF_BUILD}")
elif [[ "$IS_SUN_SPARCv9" -eq 1 ]]; then
    AUTOCONF_BUILD=$(${SED} 's/sparc/sparcv9/g' <<< "${AUTOCONF_BUILD}")
fi

export AUTOCONF_BUILD

###############################################################################

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32,
# /usr/local/lib64 and /usr/local/lib/64. We drive a test compile
# using the supplied compiler and flags.
if ${TEST_CC} ${CFLAGS} programs/test-64bit.c -o "$outfile" &>/dev/null
then
    IS_64BIT=1
    IS_32BIT=0
    INSTX_BITNESS=64
else
    IS_64BIT=0
    IS_32BIT=1
    INSTX_BITNESS=32
fi

# Some of the BSDs install user software into /usr/local.
# We don't want to overwrite the system installed software.
if [[ "$IS_BSD_FAMILY" -ne 0 ]]; then
    DEF_PREFIX="/opt/local"
else
    DEF_PREFIX="/usr/local"
fi

# Don't override a user choice of INSTX_PREFIX
if [[ -z "${INSTX_PREFIX}" ]]; then
    INSTX_PREFIX="$DEF_PREFIX"
fi

# RPATH's and their history at https://lekensteyn.nl/rpath.html.
# $ORIGIN on Linux should be available back to about 1998.
# We feature test for INSTX_OPATH and INSTX_RPATH below.
# AIX also needs -bsvr4; while HP-UX uses -Wl,+b.

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    DEF_LIBDIR="${INSTX_PREFIX}/lib"
    DEF_RPATH="${INSTX_PREFIX}/lib"
    DEF_OPATH="'""\$ORIGIN/../lib""'"
elif [[ "$IS_DARWIN" -ne 0 ]]; then
    DEF_LIBDIR="${INSTX_PREFIX}/lib"
    DEF_RPATH="${INSTX_PREFIX}/lib"
    DEF_OPATH="@loader_path/../lib"
elif [[ "$IS_RH_FAMILY" -ne 0 ]] && [[ "$IS_64BIT" -ne 0 ]]; then
    DEF_LIBDIR="${INSTX_PREFIX}/lib64"
    DEF_RPATH="${INSTX_PREFIX}/lib64"
    DEF_OPATH="'""\$ORIGIN/../lib64""'"
else
    DEF_LIBDIR="${INSTX_PREFIX}/lib"
    DEF_RPATH="${INSTX_PREFIX}/lib"
    DEF_OPATH="'""\$ORIGIN/../lib""'"
fi

# Don't override a user choice of INSTX_LIBDIR. Also see
# https://blogs.oracle.com/dipol/dynamic-libraries,-rpath,-and-mac-os
if [[ -z "${INSTX_LIBDIR}" ]]; then
    INSTX_LIBDIR="$DEF_LIBDIR"
fi
if [[ -z "${INSTX_SRCDIR}" ]]; then
    INSTX_SRCDIR="$INSTX_PREFIX/src"
fi
if [[ -z "$INSTX_RPATH" ]]; then
    INSTX_RPATH="$DEF_RPATH"
fi
if [[ -z "$INSTX_OPATH" ]]; then
    INSTX_OPATH="$DEF_OPATH"
fi

# Remove duplicate and trailing slashes.
INSTX_PREFIX="$(echo ${INSTX_PREFIX} | tr -s '/' | ${SED} -e 's/\/$//g')"
INSTX_LIBDIR="$(echo ${INSTX_LIBDIR} | tr -s '/' | ${SED} -e 's/\/$//g')"
INSTX_SRCDIR="$(echo ${INSTX_SRCDIR} | tr -s '/' | ${SED} -e 's/\/$//g')"
INSTX_RPATH="$(echo ${INSTX_RPATH} | tr -s '/' | ${SED} -e 's/\/$//g')"
INSTX_OPATH="$(echo ${INSTX_OPATH} | tr -s '/' | ${SED} -e 's/\/$//g')"

export INSTX_BITNESS
export INSTX_PREFIX INSTX_LIBDIR INSTX_SRCDIR
export INSTX_RPATH INSTX_OPATH

###############################################################################

# Add our path since we know we are using the latest binaries.
# Strip duplicate, leading and trailing colons. This will bite
# us for the Wget we build for PREFIX. It is having problems
# with some multibyte names on Ubuntu.
PATH=$(echo "${INSTX_PREFIX}/bin:$PATH" | tr -s ':' | ${SED} -e 's/^:\(.*\)/\1/' | ${SED} -e 's/:$//g')
export PATH

###############################################################################

cc_result=$(${TEST_CC} -fPIC -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_pic="-fPIC"
else
    cc_result=$(${TEST_CC} -qpic -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_pic="-qpic"
    else
        cc_result=$(${TEST_CC} -KPIC -o "$outfile" "$infile" 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            opt_pic="-KPIC"
        fi
    fi
fi

# Ugh... C++11 support as required. Things may still break.
cc_result=$(${TEST_CXX} -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    INSTX_CXX11=1
else
    cc_result=$(${TEST_CXX} -std=gnu++11 -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        INSTX_CXX11_OPT="-std=gnu++11"
        INSTX_CXX11=1
    else
        cc_result=$(${TEST_CXX} -std=c++11 -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            INSTX_CXX11_OPT="-std=c++11"
            INSTX_CXX11=1
        fi
    fi
fi

# Ugh... C++14 support as required. Things may still break.
cc_result=$(${TEST_CXX} -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    INSTX_CXX14=1
else
    cc_result=$(${TEST_CXX} -std=gnu++14 -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        INSTX_CXX14_OPT="-std=gnu++14"
        INSTX_CXX14=1
    else
        cc_result=$(${TEST_CXX} -std=c++14 -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            INSTX_CXX14_OPT="-std=c++14"
            INSTX_CXX14=1
        fi
    fi
fi

# patchelf needs C++11 support
# echo "INSTX_CXX11: $INSTX_CXX11"
INSTX_CXX11="${INSTX_CXX11:-0}"
INSTX_CXX14="${INSTX_CXX14:-0}"

export INSTX_CXX11 INSTX_CXX11_OPT INSTX_CXX14 INSTX_CXX14_OPT

# For the benefit of the programs and libraries. Make them run faster.
cc_result=$(${TEST_CC} -march=native -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_native="-march=native"
fi

# PowerMac's with 128-bit long double. Gnulib and GetText expect 64-bit long double.
cc_result=$(${TEST_CC} -o "$outfile" programs/test-128bit-double.c 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    if [[ $("./$outfile") == "106" ]]; then
        opt_64bit_dbl="-mlong-double-64"
    fi
fi

cc_result=$(${TEST_CC} -pthread -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_pthread="-pthread"
fi

# Switch from -march=native to something more appropriate
if [[ $(${EGREP} -i -c 'armv7' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    cc_result=$(${TEST_CC} -march=armv7-a -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_armv7="-march=armv7-a"
    fi
fi
# See if we can upgrade to ARMv7+NEON
if [[ $(${EGREP} -i -c 'neon' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    cc_result=$(${TEST_CC} -march=armv7-a -mfpu=neon -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_ARM_NEON=1
        opt_armv7="-march=armv7-a -mfpu=neon"
    fi
fi
# See if we can upgrade to ARMv8
if [[ $(${EGREP} -i -c 'asimd' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    cc_result=$(${TEST_CC} -march=armv8-a -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_ARMV8=1
        opt_armv8="-march=armv8-a"
    fi
fi
if [[ $(sysctl -a 2>/dev/null | ${EGREP} -i -c 'hw.optional.arm64: 1') -ne 0 ]]; then
    cc_result=$(${TEST_CC} -march=armv8-a -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_ARMV8=1
        opt_armv8="-march=armv8-a"
    fi
fi
# See if we can upgrade to Altivec
if [[ $(${EGREP} -i -c 'altivec' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    cc_result=$(${TEST_CC} -maltivec -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_ALTIVEC=1
        opt_altivec="-maltivec"
    fi
fi
# See if we can upgrade to Altivec
if [[ $(sysctl -a 2>/dev/null | ${EGREP} -i -c 'hw.optional.altivec: 1') -ne 0 ]]; then
    cc_result=$(${TEST_CC} -maltivec -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_ALTIVEC=1
        opt_altivec="-maltivec"
    fi
fi
# See if we can upgrade to Power8
if [[ $(${EGREP} -i -c 'crypto' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    cc_result=$(${TEST_CC} -mcpu=power8 -maltivec -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        IS_POWER8=1
        opt_power8="-mcpu=power8 -maltivec"
    fi
fi

# See if -Wl,-rpath,$ORIGIN/../lib works
cc_result=$(${TEST_CC} -Wl,-rpath,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_opath="-Wl,-rpath,$INSTX_OPATH"
fi
cc_result=$(${TEST_CC} -Wl,-R,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_opath="-Wl,-R,$INSTX_OPATH"
fi
cc_result=$(${TEST_CC} -Wl,-R,$INSTX_OPATH -bsvr4 -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_opath="-Wl,-R,$INSTX_OPATH -bsvr4"
fi
cc_result=$(${TEST_CC} -Wl,+b,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_opath="-Wl,+b,$INSTX_OPATH"
fi

# See if -Wl,-rpath,${libdir} works.
cc_result=$(${TEST_CC} -Wl,-rpath,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_rpath="-Wl,-rpath,$INSTX_RPATH"
fi
cc_result=$(${TEST_CC} -Wl,-R,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_rpath="-Wl,-R,$INSTX_RPATH"
fi
cc_result=$(${TEST_CC} -Wl,-R,$INSTX_RPATH -bsvr4 -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_rpath="-Wl,-R,$INSTX_RPATH -bsvr4"
fi
cc_result=$(${TEST_CC} -Wl,+b,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_rpath="-Wl,+b,$INSTX_RPATH"
fi

# See if RUNPATHs are available. new-dtags convert a RPATH to a RUNPATH.
cc_result=$(${TEST_CC} -Wl,--enable-new-dtags -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_new_dtags="-Wl,--enable-new-dtags"
fi

# http://www.sco.com/developers/gabi/latest/ch5.dynamic.html#shobj_dependencies
cc_result=$(${TEST_CC} ${opt_opath} -Wl,-z,origin -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_origin="-Wl,-z,origin"
fi

cc_result=$(${TEST_CC} -Wl,--no-as-needed -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_no_as_needed="-Wl,--no-as-needed"
fi

# OS X linker and install names
cc_result=$(${TEST_CC} -headerpad_max_install_names -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    opt_max_header_pad="-headerpad_max_install_names"
fi

# Debug versus release builds
if [[ -n "$INSTX_DEBUG" ]]; then
    opt_cppflags_build="-DDEBUG"
else
    opt_cppflags_build="-DNDEBUG"
fi

# Debug symbols
if [[ -z "$opt_sym" ]]; then
    cc_result=$(${TEST_CC} -g2 -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_sym="-g2"
    else
        cc_result=$(${TEST_CC} -g -o "$outfile" "$infile" 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            opt_sym="-g"
        fi
    fi

    # If we are building under the sanitizers with GCC or Clang, just use -g3
    if [[ -n "$INSTX_UBSAN" || -n "$INSTX_ASAN" || -n "$INSTX_MSAN" ]]; then
        opt_sym="-g3"
    fi

    # If we are building a debug build with GCC or Clang, just use -g3
    if [[ -n "$INSTX_DEBUG" ]]; then
        opt_sym="-g3"
    fi
fi

# Optimizations
if [[ -z "$opt_optimize" ]]; then
    cc_result=$(${TEST_CC} -O2 -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_optimize="-O2"
    else
        cc_result=$(${TEST_CC} -O -o "$outfile" "$infile" 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            opt_optimize="-O"
        fi
    fi

    # If we are building under the sanitizers with GCC or Clang, just use -O1
    if [[ -n "$INSTX_UBSAN" || -n "$INSTX_ASAN" || -n "$INSTX_MSAN" ]]; then
        opt_optimize="-O1"
    fi

    # If we are building a debug build with GCC or Clang, just use -O0
    if [[ -n "$INSTX_DEBUG" ]]; then
        opt_optimize="-O0"
    fi
fi

# Location to install the sources
# https://alex.dzyoba.com/blog/gdb-source-path/
if [[ "${IS_LINUX}" -ne 0 ]]; then
    cc_result=$(${TEST_CC} -g -fdebug-prefix-map=${PWD}=${PWD} -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        INSTX_DEBUG_MAP=1
        export INSTX_DEBUG_MAP
    fi
fi

# Perl does not add -lm when needed
cc_result=$(${TEST_CC} -o "$outfile" "$infile" -lm 2>&1 | wc -w)
if [[ "$cc_result" -eq 0 ]]; then
    INSTX_LIBM=1
    export INSTX_LIBM
fi

# OpenBSD does not have -ldl
if [[ -z "$opt_dl" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -ldl 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_dl="-ldl"
    fi
fi

if [[ -z "$opt_libpthread" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -lpthread 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_libpthread="-lpthread"
    fi
fi

# -fno-sanitize-recover causes an abort(). Useful for test
# programs that swallow UBsan output and pretty print "OK"
if [[ -z "$opt_san_norecover" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize=undefined -fno-sanitize-recover=all 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_san_norecover="-fno-sanitize-recover=all"
    else
        cc_result=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize=undefined -fno-sanitize-recover 2>&1 | wc -w)
        if [[ "$cc_result" -eq 0 ]]; then
            opt_san_norecover="-fno-sanitize-recover"
        fi
    fi
fi

# Disable LTO, sometimes
if [[ -z "$opt_no_lto" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -fno-lto 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_no_lto="-fno-lto"
    fi
fi

# Msan option
if [[ -z "$opt_msan_origin" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize-memory-track-origins 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_msan_origin=1
    fi
fi

# GOT and PLT hardening
if [[ -z "$opt_relro" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,relro 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_relro="-Wl,-z,relro"
    fi
fi

if [[ -z "$opt_now" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,now 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_now="-Wl,-z,now"
    fi
fi

# NX stacks
if [[ -z "$opt_as_nxstack" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -Wa,--noexecstack 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_as_nxstack="-Wa,--noexecstack"
    fi
fi

if [[ -z "$opt_ld_nxstack" ]]; then
    cc_result=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,noexecstack 2>&1 | wc -w)
    if [[ "$cc_result" -eq 0 ]]; then
        opt_ld_nxstack="-Wl,-z,noexecstack"
    fi
fi

###############################################################################

# CA cert path? Also see http://gagravarr.org/writing/openssl-certs/others.shtml
# For simplicity use ${INSTX_PREFIX}/etc/pki. Avoid about 10 different places.

INSTX_CACERT_PATH="${INSTX_PREFIX}/etc/pki"
INSTX_CACERT_FILE="${INSTX_PREFIX}/etc/pki/cacert.pem"
INSTX_ROOTKEY_PATH="${INSTX_PREFIX}/etc/unbound"
INSTX_ROOTKEY_FILE="${INSTX_PREFIX}/etc/unbound/dnsroot.key"
INSTX_ICANN_PATH="${INSTX_PREFIX}/etc/unbound"
INSTX_ICANN_FILE="${INSTX_PREFIX}/etc/unbound/icannbundle.pem"

export INSTX_CACERT_PATH INSTX_CACERT_FILE
export INSTX_ROOTKEY_PATH INSTX_ROOTKEY_FILE
export INSTX_ICANN_PATH INSTX_ICANN_FILE

###############################################################################

opt_pkgconfig=("${INSTX_LIBDIR}/pkgconfig")
opt_cppflags=("-I${INSTX_PREFIX}/include" "${opt_cppflags_build}")
opt_cflags=("$opt_sym" "$opt_optimize")
opt_cxxflags=("$opt_sym" "$opt_optimize")
opt_asflags=()
opt_ldflags=("-L${INSTX_LIBDIR}")
opt_ldlibs=()

if [[ -n "$CFLAGS64" ]]
then
    opt_cflags[${#opt_cflags[@]}]="$CFLAGS64"
    opt_cxxflags[${#opt_cxxflags[@]}]="$CFLAGS64"
    opt_ldflags[${#opt_ldflags[@]}]="$CFLAGS64"
fi

if [[ -n "$opt_64bit_dbl" ]]
then
    opt_cflags[${#opt_cflags[@]}]="$opt_64bit_dbl"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_64bit_dbl"
fi

# Debug, UBsan, Asan, Msan and Analyzer builds
if [[ -n "$INSTX_DEBUG" ]]; then
    opt_cppflags[${#opt_cppflags[@]}]="-DTEST_DEBUG=1"
    opt_cflags[${#opt_cflags[@]}]="-fno-omit-frame-pointer"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fno-omit-frame-pointer"

elif [[ -n "$INSTX_UBSAN" ]]; then
    opt_cppflags[${#opt_cppflags[@]}]="-DTEST_UBSAN=1"
    opt_cflags[${#opt_cflags[@]}]="-fsanitize=undefined"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fsanitize=undefined"
    opt_ldflags[${#opt_ldflags[@]}]="-fsanitize=undefined"

    if [[ -n "$opt_san_norecover" ]]; then
        opt_cflags[${#opt_cflags[@]}]="$opt_san_norecover"
        opt_cxxflags[${#opt_cxxflags[@]}]="$opt_san_norecover"
        opt_ldflags[${#opt_ldflags[@]}]="$opt_san_norecover"
    fi

elif [[ -n "$INSTX_ASAN" ]]; then
    opt_cppflags[${#opt_cppflags[@]}]="-DTEST_ASAN=1"
    opt_cflags[${#opt_cflags[@]}]="-fsanitize=address"
    opt_cflags[${#opt_cflags[@]}]="-fno-omit-frame-pointer"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fsanitize=address"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fno-omit-frame-pointer"
    opt_ldflags[${#opt_ldflags[@]}]="-fsanitize=address $opt_no_lto"

# Requires GCC 10, like on Fedora 32
elif [[ -n "$INSTX_ANALYZE" ]]; then
    opt_cppflags[${#opt_cppflags[@]}]="-DTEST_ANALYZE=1"
    opt_cflags[${#opt_cflags[@]}]="-fanalyzer"
    opt_cflags[${#opt_cflags[@]}]="-fno-omit-frame-pointer"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fanalyzer"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fno-omit-frame-pointer"
    opt_ldflags[${#opt_ldflags[@]}]="-fanalyzer"

elif [[ -n "$INSTX_MSAN" ]]; then
    opt_cppflags[${#opt_cppflags[@]}]="-DTEST_MSAN=1"
    opt_cflags[${#opt_cflags[@]}]="-fsanitize=memory"
    opt_cflags[${#opt_cflags[@]}]="-fno-omit-frame-pointer"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fsanitize=memory"
    opt_cxxflags[${#opt_cxxflags[@]}]="-fno-omit-frame-pointer"
    opt_ldflags[${#opt_ldflags[@]}]="-fsanitize=memory"
    opt_ldflags[${#opt_ldflags[@]}]="-fno-omit-frame-pointer"

    if [[ -n "$opt_msan_origin" ]]; then
        opt_cflags[${#opt_cflags[@]}]="-fsanitize-memory-track-origins"
        opt_cxxflags[${#opt_cxxflags[@]}]="-fsanitize-memory-track-origins"
        opt_ldflags[${#opt_ldflags[@]}]="-fsanitize-memory-track-origins"
    fi
fi

if [[ -n "$opt_armv8" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_armv8"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_armv8"
elif [[ -n "$opt_armv7" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_armv7"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_armv7"
elif [[ -n "$opt_native" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_native"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_native"
fi

if [[ -n "$opt_power8" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_power8"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_power8"
elif [[ -n "$opt_altivec" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_altivec"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_altivec"
fi

if [[ -n "$opt_pic" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_pic"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_pic"
fi

if [[ -n "$opt_pthread" ]]; then
    opt_cflags[${#opt_cflags[@]}]="$opt_pthread"
    opt_cxxflags[${#opt_cxxflags[@]}]="$opt_pthread"
fi

if [[ -n "$opt_as_nxstack" ]]; then
    opt_asflags[${#opt_asflags[@]}]="$opt_as_nxstack"
fi

if [[ -n "$opt_opath" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_opath"
fi

if [[ -n "$opt_rpath" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_rpath"
fi

if [[ -n "$opt_new_dtags" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_new_dtags"
fi

if [[ -n "$opt_relro" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_relro"
fi

if [[ -n "$opt_now" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_now"
fi

if [[ -n "$opt_ld_nxstack" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_ld_nxstack"
fi

if [[ -n "$opt_origin" ]]; then
    opt_ldflags[${#opt_ldflags[@]}]="$opt_origin"
fi

if [[ -n "$opt_dl" ]]; then
    opt_ldlibs[${#opt_ldlibs[@]}]="$opt_dl"
fi

if [[ -n "$opt_libpthread" ]]; then
    opt_ldlibs[${#opt_ldlibs[@]}]="$opt_libpthread"
fi

#if [[ "$IS_DARWIN" -ne 0 ]] && [[ -n "$opt_max_header_pad" ]]; then
#    opt_ldflags[${#opt_ldflags[@]}]="$opt_max_header_pad"
#fi

###############################################################################

# Used to track packages that have been built by these scripts.
# The accounting is local to a user account. There is no harm
# in rebuilding a package under another account. In April 2019
# we added INSTX_PREFIX so we could build packages in multiple
# locations. For example, /usr/local for updated packages, and
# /var/sanitize for testing packages.
if [[ -z "${INSTX_PKG_CACHE}" ]]; then
    # Change / to - for CACHE_DIR
    CACHE_DIR=$(cut -c 2- <<< "${INSTX_PREFIX}" | ${SED} 's/\//-/g')
    INSTX_PKG_CACHE="$HOME/.build-scripts/$CACHE_DIR"
    mkdir -p "${INSTX_PKG_CACHE}"
fi

export INSTX_PKG_CACHE

# If the package is older than 7 days, then rebuild it. This sidesteps the
# problem of continually rebuilding the same package when installing a
# program like Git and SSH. It also avoids version tracking by automatically
# building a package after 7 days (even if it is the same version).
IFS= find "${INSTX_PKG_CACHE}" -type f -mtime +7 -print | while read -r pkg
do
    # printf "Setting %s for rebuild\n" "$pkg"
    rm -f "$pkg" 2>/dev/null
done

###############################################################################

# Solaris and OS X may have the GNU tools.
if [[ -n "$(command -v glibtool 2>/dev/null)" ]];
then
    LIBTOOL=glibtool
    export LIBTOOL
    if [[ -n "$(command -v glibtoolize 2>/dev/null)" ]];
    then
        LIBTOOLIZE=glibtoolize
        export LIBTOOLIZE
    fi
fi

###############################################################################

# setup-cacerts.sh does not source the environment, so we can't use the
# variables in the setup-cacerts.sh script. Other scripts can use them.

LETS_ENCRYPT_ROOT="$HOME/.build-scripts/cacert/lets-encrypt-roots.pem"
IDENTRUST_ROOT="$HOME/.build-scripts/cacert/identrust-root-x3.pem"
GO_DADDY_ROOT="$HOME/.build-scripts/cacert/godaddy-root-ca.pem"
DIGICERT_ROOT="$HOME/.build-scripts/cacert/digicert-root-ca.pem"
DIGITRUST_ROOT="$HOME/.build-scripts/cacert/digitrust-root-ca.pem"
USERTRUST_ROOT="$HOME/.build-scripts/cacert/usertrust-root-ca.pem"
GITHUB_CA_ZOO="$HOME/.build-scripts/cacert/github-ca-zoo.pem"
GITLAB_ROOT="$HOME/.build-scripts/cacert/sectigo-ca.pem"

# Some downloads need the CA Zoo due to multiple redirects
THE_CA_ZOO="$HOME/.build-scripts/cacert/cacert.pem"

export LETS_ENCRYPT_ROOT IDENTRUST_ROOT GO_DADDY_ROOT
export DIGICERT_ROOT DIGITRUST_ROOT USERTRUST_ROOT
export GITHUB_CA_ZOO THE_CA_ZOO

###############################################################################

# Delete old log files from the last build
find . -name '*.log.zip' -exec rm -f {} \;

###############################################################################

# Paydirt...
export INSTX_PKGCONFIG="${opt_pkgconfig[*]}"
export INSTX_CPPFLAGS="${opt_cppflags[*]}"
export INSTX_CFLAGS="${opt_cflags[*]}"
export INSTX_CXXFLAGS="${opt_cxxflags[*]}"
export INSTX_ASFLAGS="${opt_asflags[*]}"
export INSTX_LDFLAGS="${opt_ldflags[*]}"
export INSTX_LDLIBS="${opt_ldlibs[*]}"
export INSTX_JOBS="${INSTX_JOBS:-2}"

# Print a summary

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    printf "\n"
    printf "%s\n" "Solaris tools:"
    printf "\n"
    printf "%s\n" "     sed: $(command -v sed)"
    printf "%s\n" "     awk: $(command -v awk)"
    printf "%s\n" "    grep: $(command -v grep)"
    if [[ -n "$LEX" ]]; then
        printf "%s\n" "     lex: $LEX"
    else
        printf "%s\n" "     lex: $(command -v lex)"
        printf "%s\n" "    flex: $(command -v flex)"
    fi
    if [[ -n "$YACC" ]]; then
        printf "%s\n" "     lex: $YACC"
    else
        printf "%s\n" "    yacc: $(command -v yacc)"
        printf "%s\n" "   bison: $(command -v bison)"
    fi
fi

printf "\n"
printf "%s\n" "Common flags and options:"
printf "\n"
printf "%s\n" "  INSTX_BITNESS: ${INSTX_BITNESS}-bits"
printf "%s\n" "   INSTX_PREFIX: ${INSTX_PREFIX}"
printf "%s\n" "   INSTX_LIBDIR: ${INSTX_LIBDIR}"
printf "%s\n" "    INSTX_OPATH: ${INSTX_OPATH}"
printf "%s\n" "    INSTX_RPATH: ${INSTX_RPATH}"
printf "\n"
printf "%s\n" " AUTOCONF_BUILD: ${AUTOCONF_BUILD}"
printf "%s\n" "PKG_CONFIG_PATH: ${INSTX_PKGCONFIG}"
printf "%s\n" "       CPPFLAGS: ${INSTX_CPPFLAGS}"

if [[ -n "${INSTX_ASFLAGS}" ]]; then
    printf "%s\n" "        ASFLAGS: ${INSTX_ASFLAGS}"
fi

printf "%s\n" "         CFLAGS: ${INSTX_CFLAGS}"
printf "%s\n" "       CXXFLAGS: ${INSTX_CXXFLAGS}"
printf "%s\n" "        LDFLAGS: ${INSTX_LDFLAGS}"
printf "%s\n" "         LDLIBS: ${INSTX_LDLIBS}"
printf "\n"

printf "%s\n" "   CC: $(command -v "${CC}")"
printf "%s\n" "  CXX: $(command -v "${CXX}")"
printf "%s\n" " WGET: $WGET"
printf "\n"

###############################################################################

# Too many GNU programs and libraries leak.
# The world must lower its standards to GNU.
if [[ -n "$INSTX_ASAN" ]]; then
    echo ""
    echo "**********************************************************************"
    echo "Disabling ASAN leak detection because GNU software leaks like a sieve."
    echo "You must lower your standards to that of the GNU organization."
    echo "https://www.gnu.org/prep/standards/standards.html#index-memory-usage."
    echo "**********************************************************************"
    ASAN_OPTIONS='detect_leaks=0'
    export ASAN_OPTIONS
fi

###############################################################################

SETUP_ENVIRON_DONE="yes"
export SETUP_ENVIRON_DONE

[[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
