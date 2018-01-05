#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans Autotools when Autotools was installed
# by build-autotools.sh at /usr/local.

# Run the script like so:
#
#    sudo ./clean-autotools.sh

# The extra gyrations around Perl files are due to Perl's
# Autom4te::ChannelDefs getting whacked along with the
# Autotools files. Its non-trivial to reinstall the missing
# Perl files because the sources must be compiled again.

echo "Cleaning autom4te..."
FILES=$(find /usr/local -name 'autom4te' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning autopoint..."
FILES=$(find /usr/local -name 'autopoint' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning autoconf..."
FILES=$(find /usr/local -name 'autoconf' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning autoconf..."
FILES=$(find /usr/local -name 'autoreconf' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning autoheader..."
FILES=$(find /usr/local -name 'autoheader' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning automake..."
FILES=$(find /usr/local -name 'automake' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning autoupdate..."
FILES=$(find /usr/local -name 'autoupdate' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "Cleaning aclocal..."
FILES=$(find /usr/local -name 'aclocal*' 2>/dev/null)
for file in "${FILES[*]}"; do
    DONT_DELETE=$(echo "$file" | grep -c -e '\.pm')
    if [[ "$DONT_DELETE" -eq "0" ]]; then
        rm -f "$file"
    fi
done

echo "You may need to update libtool if you did so previously."
echo "Please update your shell's program cache."
[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r
