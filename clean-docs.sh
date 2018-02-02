#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans documentation placed in /usr/local/share.

# Run the script like so:
#
#    sudo ./clean-docs.sh

PACKAGES=(
	automake b2sum bzip cacert clamav
	cryptopp curl emacs environ expat
	gettext git gmp gnutls guile
	gzip iconv icu idn less
	libffi libtool mawk ncurses nettle
	openssl openvpn p11kit pcre	perl
	psl readline sed ssh tar
	tasn1 termcap tinyxml2 unbound
	unistr wget xz zlib
)

# Straglers
PACKAGES+=(b2sum  bzdiff   bzfgrep  bzip2   bzmore)
PACKAGES+=(bzcmp  bzegrep  bzgrep   bzless)

echo ""
echo "Cleaing shared documentation"

for dir in "${PACKAGES[@]}"; do
    find /usr/local/man -type d -name "$dir*" -exec rm -rf {} \; 2>/dev/null
done

[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r
