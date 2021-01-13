#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton

# This script builds a handful of packages that are used by most GNU packages.
# The packages built by this script are Patchelf, Ncurses, Readline, iConvert
# and GetText.
#
# GetText is built in two stages. First, the iConv/GetText pair is built for
# its circular dependency. Second, the final GetText is build which includes
# libunistring and libxml2.
#
# Most GNU packages will just call build-base.sh to get the common packages
# out of the way. Non-GNU packages can call the script, too.

PKG_NAME=gnu-base

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "${SUDO_PASSWORD_DONE}" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

# GetText will be checked in build-gettext-final.sh

export INSTX_DISABLE_GETTEXT_CHECK=1

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

unset INSTX_DISABLE_GETTEXT_CHECK

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-libxml2.sh
then
    echo "Failed to build libxml2"
    exit 1
fi

###############################################################################

if ! ./build-gettext-final.sh
then
    echo "Failed to build GetText final"
    exit 1
fi

###############################################################################

# Trigger a rebuild of PCRE2

rm -f "$INSTX_PKG_CACHE/pcre2"

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

# Trigger a rebuild of IDN2

rm -f "$INSTX_PKG_CACHE/idn2"

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

touch "$INSTX_PKG_CACHE/$PKG_NAME"

exit 0
