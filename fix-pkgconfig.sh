#!/usr/bin/env bash

# This script fixes *.pc files. It removes extra fodder from Libs
# and Libs.private. It is needed because some configure scripts
# cannot handle the extra options in pkg config files. For example,
# Zile fails to find Ncurses because Ncurses uses the following in
# its *.pc file:
#     Libs: -L<path> -Wl,-rpath,<path> -lncurses
# Zile can find the libraries when using:
#     Libs: -L<path> -lncurses

echo ""
echo "**********************"
echo "Fixing *.pc files"
echo "**********************"

if [[ -n "$1" ]]; then
    PROG_PATH="$1"
else
    PROG_PATH="${INSTX_TOPDIR}/programs"
fi

CXX="${CXX:-CC}"
if ! "${CXX}" "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
then
    if ! g++ "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
    then
        if ! clang++ "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
        then
            echo "Failed to build fix-pkgconfig"
            exit 1
        fi
    fi
fi

IFS= find "./" -iname '*.pc' -print | while read -r file
do
    # Display filename, strip leading "./"
    this_file=$(echo "$file" | tr -s '/' | cut -c 3-)
    echo "patching ${this_file}..."

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+rw "$file"
    ./fix-pkgconfig.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

exit 0
