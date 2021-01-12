#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Readline from sources. Ncurses should
# be built first. If Ncurses is built, then tinfo will be
# used. If tinfow is not used, then UP and PC go missing.

READLN_TAR=readline-8.0.tar.gz
READLN_DIR=readline-8.0
PKG_NAME=readline

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "${SUDO_PASSWORD_DONE}" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== Readline ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$READLN_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/readline/$READLN_TAR"
then
    echo "Failed to download Readline"
    exit 1
fi

rm -rf "$READLN_DIR" &>/dev/null
gzip -d < "$READLN_TAR" | tar xf -
cd "$READLN_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/readline.patch ]]; then
    patch -u -p0 < ../patch/readline.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

# Fix missing -ltinfo for *.pc files
IFS= find "$PWD" -name '*.pc.in' -print | while read -r file
do
    touch -a -m -r "$file" "$file.timestamp"
    chmod u+w "$file" && cp -p "$file" "$file.fixed"

    sed -e 's/-lreadline/-lreadline -ltinfow/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"

    chmod a+r "$file" && chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

if [[ "$IS_DARWIN" -ne 0 ]]; then
    READLINE_CPPFLAGS="-DNEED_EXTERN_PC"
else
    READLINE_CPPFLAGS=""
fi

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS} ${READLINE_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="-ltinfow ${INSTX_LDLIBS}" \
    LIBS="-ltinfow ${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-shared \
    --enable-multibyte \
    --disable-install-examples

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Readline"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    #printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S rm -f "${INSTX_LIBDIR}/libreadline*.*"
    #printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S rm -f "${INSTX_LIBDIR}/libhistory*.*"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    #printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S rm -f "${INSTX_LIBDIR}/.*.old"
else
    #rm -f "${INSTX_LIBDIR}/libreadline*.*"
    #rm -f "${INSTX_LIBDIR}/libhistory*.*"
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    #rm -rf "${INSTX_LIBDIR}/.*.old"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true
then
    ARTIFACTS=("$READLN_TAR" "$READLN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
