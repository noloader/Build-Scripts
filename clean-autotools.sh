#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans Autotools when Autotools was installed
# by build-autotools.sh at /usr/local.

# Run the script like so:
#
# sudo ./clean-autotools.sh

echo "Cleaning autom4te..."
find /usr/local -name 'autom4te' -exec rm -rf {} \; 2>/dev/null

echo "Cleaning autopoint..."
find /usr/local -name 'autopoint' -exec rm -rf {} \; 2>/dev/null

echo "Cleaning autoconf..."
find /usr/local -name 'autoconf' -exec rm -rf {} \; 2>/dev/null

echo "Cleaning autoheader..."
find /usr/local -name 'autoheader' -exec rm -rf {} \;

echo "Cleaning automake..."
find /usr/local -name 'automake' -exec rm -rf {} \;

echo "Cleaning autoupdate..."
find /usr/local -name 'autoupdate' -exec rm -rf {} \;

echo "Cleaning aclocal..."
find /usr/local -name 'aclocal*' -exec rm -rf {} \;

echo "Done. Please update your shell's program cache."
[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r
