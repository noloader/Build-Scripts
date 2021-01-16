#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script source files from $1 to $2 for debugging.

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
mkdir -p "${dest_dir}"

IFS= find "./" \( -name '*.h' -o -name '*.c' -o -name '*.cc' -o \
                  -name '*.cpp' -o -name '*.cxx' -o -name '*.CC' -o \
                  -name '*.s' -o -name '*.S' \) -print | while read -r file
do
    # This trims the leading "./" in "./foo.c".
    file=$(echo "${file}" | tr -s '/' | cut -c 3-);
    cp --parents --preserve=mode,timestamps "${file}" "${dest_dir}"
done

exit 0
