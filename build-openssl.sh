#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

# OpenSSL 1.1.1 requires Perl 5.10. If Perl 5.10 is available,
# then OpenSSL 1.1.1 is built. Otherwise OpenSSL 1.0.2 is built.

# OpenSSL 1.0.2 is end of life. It was last updated in
# December 2019. But it is better than the OpenSSL gear on
# an old platform, which can sometimes be OpenSSL 0.9.8.

PKG_NAME=openssl

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "${INSTX_PKG_CACHE}/${PKG_NAME}" ]]; then
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

if [[ -n "$(command -v perl 2>/dev/null)" ]]; then
    PERL_MAJ=$(perl -V | head -n 1 | awk '{ print $6 }')
    PERL_MIN=$(perl -V | head -n 1 | awk '{ print $8 }')
else
    PERL_MAJ=0
    PERL_MIN=0
fi

# Trim stray decimal points resent in old Perl
PERL_MAJ=$(echo "${PERL_MAJ}" | awk -F '.' '{print $1}')
PERL_MIN=$(echo "${PERL_MIN}" | awk -F '.' '{print $1}')

# OpenSSL 1.1.1 needs Perl 5.10 or above.
if [[ "$PERL_MAJ" -lt 5 || ("$PERL_MAJ" -eq 5 && "$PERL_MIN" -lt 10) ]]
then

    printf "\nFound PERL_MAJ=%d, PERL_MIN=%d, using OpenSSL 1.0.2\n" "${PERL_MAJ}" "${PERL_MIN}"

    if ! ./build-openssl-1.0.2.sh
    then
        echo "Failed to build OpenSSL 1.0.2"
        exit 1
    fi
else

    printf "\nFound PERL_MAJ=%d, PERL_MIN=%d, using OpenSSL 1.1.1\n" "${PERL_MAJ}" "${PERL_MIN}"

    if ! ./build-openssl-1.1.1.sh
    then
        echo "Failed to build OpenSSL 1.1.1"
        exit 1
    fi
fi

exit 0

