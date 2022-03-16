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
echo "************************"
echo "Fixing configure scripts"
echo "************************"

if [[ -n "$1" ]]; then
    PROG_PATH="$1"
else
    PROG_PATH="${INSTX_TOPDIR}/programs"
fi

CXX="${CXX:-CC}"
if ! "${CXX}" "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
then
    if ! g++ "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
    then
        if ! clang++ "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
        then
            echo "Failed to build fix-configure"
            exit 1
        fi
    fi
fi

IFS= find "./" -name 'configure.ac' -print | while read -r file
do
    # Display filename, strip leading "./"
    this_file=$(echo "$file" | tr -s '/' | cut -c 3-)
    echo "patching ${this_file}..."

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"; chmod a+x "$file"
    ./fix-configure.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file";
    chmod a+x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

IFS= find "./" -name 'configure' -print | while read -r file
do
    # Display filename, strip leading "./"
    this_file=$(echo "$file" | tr -s '/' | cut -c 3-)
    echo "patching ${this_file}..."

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"; chmod a+x "$file"
    ./fix-configure.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file";
    chmod a+x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

echo "patching config.sub..."
IFS= find "./" -name 'config.sub' -print | while read -r file
do
    chmod a+w "$file"; chmod a+x "$file"
    cp -p "$PROG_PATH/config.sub" "$file"
    chmod a+x "$file"; chmod go-w "$file"
done

echo "patching config.guess..."
IFS= find "./" -name 'config.guess' -print | while read -r file
do
    chmod a+w "$file"; chmod a+x "$file"
    cp -p "$PROG_PATH/config.guess" "$file"
    chmod a+x "$file"; chmod go-w "$file"
done

exit 0
