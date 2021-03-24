#!/usr/bin/env bash

if [[ -z "${WGET}" ]]; then
    WGET=$(command -v wget 2>/dev/null)
fi

ca_zoo='../bootstrap/cacert.pem'
if [[ ! -f "${ca_zoo}" ]]; then
    echo "CA Zoo does not exist. Run this script from the program/ directory"
    exit 1
fi

echo "Updating config.sub"
if ! ${WGET} -q -O config.sub.new --ca-certificate="${ca_zoo}" \
    'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD';
then
    echo "config.sub download failed"
    exit 1
fi

if [[ $(wc -c < config.sub.new) -eq 0 ]]; then
    echo "config.sub download failed"
    exit 1
fi

if ! mv config.sub.new config.sub; then
    echo "Failed to copy config.sub"
fi

echo "Fixing config.sub permissions"
chmod +x config.sub
xattr -d com.apple.quarantine config.sub 2>/dev/null

echo "Updating config.guess"
if ! ${WGET} -q -O config.guess.new --ca-certificate="${ca_zoo}" \
    'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD';
then
    echo "config.sub download failed"
    exit 1
fi

if [[ $(wc -c < config.guess.new) -eq 0 ]]; then
    echo "config.sub download failed"
    exit 1
fi

if ! mv config.guess.new config.guess; then
    echo "Failed to copy config.guess"
fi

echo "Fixing config.guess permissions"
chmod +x config.guess
xattr -d com.apple.quarantine config.guess 2>/dev/null

echo "Updating bootstrap cacert.pem"
if ! ${WGET} -q -O ../bootstrap/cacert.pem.new --ca-certificate="${ca_zoo}" \
    'https://curl.se/ca/cacert.pem';
then
    echo "cacert.pem download failed"
    exit 1
fi

if [[ $(wc -c < ../bootstrap/cacert.pem.new) -eq 0 ]]; then
    echo "cacert.pem download failed"
    exit 1
fi

if ! mv ../bootstrap/cacert.pem.new ../bootstrap/cacert.pem; then
    echo "Failed to copy cacert.pem"
fi

echo "Updating bootstrap icannbundle.pem"
if ! ${WGET} -q -O ../bootstrap/icannbundle.pem.new --ca-certificate="${ca_zoo}" \
    'https://data.iana.org/root-anchors/icannbundle.pem';
then
    echo "icannbundle.pem download failed"
    exit 1
fi

if [[ $(wc -c < ../bootstrap/icannbundle.pem.new) -eq 0 ]]; then
    echo "icannbundle.pem download failed"
    exit 1
fi

if ! mv ../bootstrap/icannbundle.pem.new ../bootstrap/icannbundle.pem; then
    echo "Failed to copy icannbundle.pem"
fi

# Not correct:
#   wget -O root-anchors.p7s https://data.iana.org/root-anchors/root-anchors.p7s
#   openssl pkcs7 -print_certs -in root-anchors.p7s -inform DER -out root-anchors.pem
#   sed -i -e 's/^subject/#subject/g' -e 's/^issuer/#issuer/g' root-anchors.pem

UNBOUND_ANCHOR=$(command -v unbound-anchor 2>/dev/null)
if [[ -z "${UNBOUND_ANCHOR}" ]]; then
    UNBOUND_ANCHOR=/sbin/unbound-anchor;
fi

if [[ -f "${UNBOUND_ANCHOR}" ]]
then
    echo "Updating bootstrap dnsrootkey.pem"
    "${UNBOUND_ANCHOR}" -a ../bootstrap/dnsroot.key -u data.iana.org
    mv ../bootstrap/dnsroot.key ../bootstrap/dnsrootkey.pem
else
    echo "Failed to update bootstrap dnsrootkey.pem. Install unbound-anchor"
    exit 1
fi

exit 0
