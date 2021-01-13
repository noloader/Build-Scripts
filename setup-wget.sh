#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources.

cd "bootstrap" || exit 1

if ! ./bootstrap-wget.sh; then
    echo "Bootstrap failed for Wget"
    exit 1
fi

exit 0
