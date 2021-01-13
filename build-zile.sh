#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Zile from sources.

ZILE_TAR=zile-2.4.14.tar.gz
ZILE_DIR=zile-2.4.14
PKG_NAME=zile

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
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

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Zile ================="
echo "========================================"

echo ""
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@ Warning: Zile is in maintenance    @@"
echo "@@ mode and no longer recommended for @@"
echo "@@ use by its maintainer.             @@"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$ZILE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/zile/$ZILE_TAR"
then
    echo "Failed to download Zile"
    exit 1
fi

rm -rf "$ZILE_DIR" &>/dev/null
gzip -d < "$ZILE_TAR" | tar xf -
cd "$ZILE_DIR"

if [[ -e ../patch/zile.patch ]]; then
    patch -u -p0 < ../patch/zile.patch
    echo ""
fi

if ! "$WGET" -q -O m4/pkg.m4 --ca-certificate="$GITHUB_ROOT" \
     https://raw.githubusercontent.com/pkgconf/pkgconf/master/pkg.m4
then
    echo "Failed to update pkg.m4"
else
    chmod u+rw m4/pkg.m4
    chmod go+r m4/pkg.m4
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--with-ncurses")
CONFIG_OPTS+=("--disable-valgrind-tests")
CONFIG_OPTS+=("HELP2MAN=true")

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    CONFIG_OPTS+=("--enable-threads=solaris")
else
    CONFIG_OPTS+=("--enable-threads=posix")
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Zile"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "patching Makefiles..."
IFS= find "$PWD" -name 'Makefile' -print | while read -r file
do
    cp -p "$file" "$file.fixed"
    sed 's/-lncurses/-lncursesw -ltinfo/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "patching source files..."
if true; then
    file="src/term_curses.c"
    cp -p "$file" "$file.fixed"
    sed 's/<term.h>/"ncurses\/term.h"/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Zile"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

#MAKE_FLAGS=("check")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "**********************"
#    echo "Failed to test Zile"
#    echo "**********************"
#    bash ../collect-logs.sh "${PKG_NAME}"
#    exit 1
#fi

# Zile is impossible to test. It breaks the current terminal.
echo "**********************"
echo "Zile not tested"
echo "**********************"

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$ZILE_TAR" "$ZILE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
