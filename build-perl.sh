#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Perl from sources.

PERL_TAR=perl-5.26.1.tar.gz
PERL_DIR=perl-5.26.1

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "Perl requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
GLOBALSIGN_ROOT="$HOME/.cacert/globalsign-root-r1.pem"

###############################################################################

# Get environment if needed. We can't export it because it includes arrays.
if [[ -z "$BUILD_OPTS" ]]; then
    source ./build-environ.sh
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** Perl **********"
echo

wget --ca-certificate="$GLOBALSIGN_ROOT" "http://www.cpan.org/src/5.0/$PERL_TAR" -O "$PERL_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Perl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PERL_DIR" &>/dev/null
gzip -d < "$PERL_TAR" | tar xf -
cd "$PERL_DIR"

./Configure -des -Dextras="HTTP::Daemon HTTP::Request Test"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Perl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Perl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Perl"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

# This downloads and installs Perl's package manager

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PERL_TAR" "$PERL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-perl.sh 2>&1 | tee build-perl.log
    if [[ -e build-perl.log ]]; then
        rm -f build-perl.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
