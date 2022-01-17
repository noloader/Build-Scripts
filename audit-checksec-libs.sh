#!/usr/bin/env bash

# Download and install checksec:
#   wget https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec
#   xattr -r -d com.apple.quarantine checksec
#   chmod a+x checksec
#   sudo mv checksec /usr/bin

dir="$1"

# Ensure a directory is specified
if [[ -z "${dir}" ]]; then
    echo "Please specify a directory"
    exit 1
fi

if [[ ! -d "${dir}" ]]; then
    echo "Please specify a real directory"
    exit 1
fi

# Find a non-anemic grep
GREP=$(command -v grep 2>/dev/null)
if [[ -d /usr/gnu/bin ]]; then
    GREP=/usr/gnu/bin/grep
fi

# Ensure checksec is available
if [[ -z "${CHECKSEC}" ]]; then
    if [[ -e ./checksec ]]; then
        CHECKSEC=./checksec
    elif [[ $(command -v checksec 2>/dev/null) ]]; then
        CHECKSEC=$(command -v checksec 2>/dev/null)
    fi
fi

if [[ -z "${CHECKSEC}" ]]
then
    echo "Installing checksec"

    wget -q -O checksec 'https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec'
    chmod +x checksec

    if [[ $(uname -s | ${GREP} -i 'darwin') ]] ;then
        xattr -r -d com.apple.quarantine checksec
    fi

    CHECKSEC=./checksec
fi

if [[ $(uname -s | ${GREP} -i 'darwin') ]]; then
    LIB_EXT='*\.dylib*'
else
    LIB_EXT='*\.so*'
fi

# Find libfoo.so* files using the shell wildcard. Some libraries
# are _not_ executable and get missed in the do loop.
IFS= find "${dir}" -type f -name "$LIB_EXT" -print | while read -r file
do
    if [[ ! $(file -ibh "${file}" | ${GREP} -E "application/x-sharedlib") ]]; then continue; fi

    echo "****************************************"
    echo "${file}:"
    echo ""

    ${CHECKSEC} --file="${file}"

done
echo "****************************************"

exit 0
