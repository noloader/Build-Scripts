#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes $ORIGIN-based runpaths in Makefiles. Projects that
# generate makefiles on the fly after configure may break due to their
# cleverness. Also see https://github.com/Perl/perl5/issues/17978 and
# https://gitlab.alpinelinux.org/alpine/aports/-/issues/11655.
#
# Perl's build system is completely broken beyond repair. The broken
# runpath handling cannot be fixed with makefile patching. Also see
# https://github.com/Perl/perl5/issues/17978.
#
# We also remove -Wextra, if present. Old GCC does not know the option.
# -Wextra is a developer option, and we don't need it in production.

echo ""
echo "**********************"
echo "Fixing Makefiles"
echo "**********************"

# We want the leading single quote, and the trailing slash.
origin1=$(echo "'"'$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin2=$(echo "'"'$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')

# And with braces
origin1b=$(echo "'"'${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')
origin2b=$(echo "'"'$${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')

# And Perl
origin1p=$(echo "-Wl,-R,RIGIN/" | sed -e 's/[\/&]/\\&/g')
origin2p=$(echo "-Wl,-R,""'"'$${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')

IFS= find "./" -iname 'Makefile' -print | while read -r file
do
    # Display filename, strip leading "./"
    echo "$file" | tr -s '/' | cut -c 3-

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        -e "s/-Wextra/ /g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"
    chmod a-x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

IFS= find "./" -iname 'GNUmakefile' -print | while read -r file
do
    # Display filename, strip leading "./"
    echo "$file" | tr -s '/' | cut -c 3-

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        -e "s/-Wextra/ /g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"
    chmod a-x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

# And Perl...
IFS= find "./" -iname 'makefile*' -print | while read -r file
do
    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1p/$origin2p/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        -e "s/-Wextra/ /g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"
    chmod a-x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

exit 0
