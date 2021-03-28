#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script copies source files for debugging after installation.

# Only copy sources on Linux machines
if [[ $(uname -s | grep -i -c 'linux') -eq 0 ]]; then
    exit 0
fi

# Exit if INSTX_DEBUG_MAP is not set
INSTX_DEBUG_MAP=${INSTX_DEBUG_MAP:-0}
if [[ "${INSTX_DEBUG_MAP}" -eq 0 ]]; then
    exit 0
fi

echo ""
echo "**********************"
echo "Copying source files"
echo "**********************"

src_dir="$1"
dest_dir="$2"

if [[ -z "${src_dir}" ]]; then
    echo "Please specify a source directory"
    exit 1
fi

if [[ ! -d "${src_dir}" ]]; then
    echo "Source directory is not valid"
    exit 1
fi

if [[ -z "${dest_dir}" ]]; then
    echo "Please specify a destination directory"
    exit 1
fi

cd "${src_dir}" || exit 1
rm -rf "${dest_dir}"
mkdir -p "${dest_dir}"

IFS= find "./" \( -name '*.h' -o -name '*.hpp' -o -name '*.hxx' -o \
                  -name '*.c' -o -name '*.cc' -o \
                  -name '*.cpp' -o -name '*.cxx' -o -name '*.CC' -o \
                  -name '*.s' -o -name '*.S' \) -print | while read -r file
do
    # This trims the leading "./" in "./foo.c".
    file=$(echo -n "${file}" | tr -s '/' | cut -c 3-);
    cp --parents --preserve=timestamps "${file}" "${dest_dir}"
done

exit 0
