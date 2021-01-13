#!/usr/bin/env bash

ca_zoo='../bootstrap/cacert.pem'
if [[ ! -f "${ca_zoo}" ]]; then
    echo "CA Zoo does not exist. Run this script from the program/ directory"
    exit 1
fi

echo "Updating config.sub"
wget -q -O config.sub --ca-certificate="${ca_zoo}" 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'

if [[ $(wc -c < config.sub) -eq 0 ]]; then
    echo "config.sub download failed"
    exit 1
fi

echo "Fixing config.sub permissions"
chmod +x config.sub
xattr -d com.apple.quarantine config.sub 2>/dev/null

echo "Updating config.guess"
wget -q -O config.guess --ca-certificate="${ca_zoo}" 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'

if [[ $(wc -c < config.guess) -eq 0 ]]; then
    echo "config.sub download failed"
    exit 1
fi

echo "Fixing config.guess permissions"
chmod +x config.guess
xattr -d com.apple.quarantine config.guess 2>/dev/null

echo "Updating bootstrap cacert.pem"
wget -q -O ../bootstrap/cacert.pem --ca-certificate="${ca_zoo}" 'https://curl.se/ca/cacert.pem'

if [[ $(wc -c < ../bootstrap/cacert.pem) -eq 0 ]]; then
    echo "cacert.pem download failed"
    exit 1
fi

echo "Updating bootstrap icannbundle.pem"
wget -q -O ../bootstrap/icannbundle.pem --ca-certificate="${ca_zoo}" 'https://data.iana.org/root-anchors/icannbundle.pem'

if [[ $(wc -c < ../bootstrap/icannbundle.pem) -eq 0 ]]; then
    echo "icannbundle.pem download failed"
    exit 1
fi

# Not correct:
#   wget -O root-anchors.p7s https://data.iana.org/root-anchors/root-anchors.p7s
#   openssl pkcs7 -print_certs -in root-anchors.p7s -inform DER -out root-anchors.pem
#   sed -i -e 's/^subject/#subject/g' -e 's/^issuer/#issuer/g' root-anchors.pem

UNBOUND_ANCHOR=$(command -v unbound-anchor)
if [ -z "$UNBOUND_ANCHOR" ]; then UNBOUND_ANCHOR=/sbin/unbound-anchor; fi

if [[ $(ls "$UNBOUND_ANCHOR" 2>/dev/null) ]]
then
    echo "Updating bootstrap dnsroot.key"
    "${UNBOUND_ANCHOR}" -a ../bootstrap/dnsroot.key -u data.iana.org
else
    echo "Failed to update bootstrap dnsroot.key. Install unbound-anchor"
    exit 1
fi

exit 0
