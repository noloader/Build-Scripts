#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Sqlite3 from sources.

SQLITE_VER=3370200
SQLITE_TAR=sqlite-autoconf-${SQLITE_VER}.tar.gz
SQLITE_DIR=sqlite-autoconf-${SQLITE_VER}
PKG_NAME=sqlite3

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

#Sqlite only needs Readline
if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== Sqlite3 ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Sqlite3 ${SQLITE_VER}..."

if ! "${WGET}" -q -O "$SQLITE_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://sqlite.org/2021/$SQLITE_TAR"
then
    echo "Failed to download Sqlite3"
    exit 1
fi

rm -rf "$SQLITE_DIR" &>/dev/null
gzip -d < "$SQLITE_TAR" | tar xf -
cd "$SQLITE_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/sqlite3.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/sqlite3.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

# Compile: https://sqlite.org/compile.html
# FTS3 and FTS4: https://sqlite.org/fts3.html
# FTS5: https://sqlite.org/fts5.html
# R*Tree: https://sqlite.org/rtree.html
# JSON1: https://sqlite.org/json1.html

    sqlite_cppflags="${INSTX_CPPFLAGS}"
    sqlite_cppflags="${sqlite_cppflags} -DSQLITE_OMIT_DEPRECATED"
    sqlite_cppflags="${sqlite_cppflags} -DSQLITE_TEMP_STORE=2"
    sqlite_cppflags="${sqlite_cppflags} -DSQLITE_ENABLE_COLUMN_METADATA"
    sqlite_cppflags="${sqlite_cppflags} -DSQLITE_SOUNDEX"
    sqlite_cppflags="${sqlite_cppflags} -DSQLITE_HAVE_ZLIB"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${sqlite_cppflags}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static \
    --enable-shared \
    --enable-readline \
    --enable-threadsafe \
    --enable-dynamic-extensions \
    --enable-fts4 \
    --enable-fts5 \
    --enable-json1 \
    --enable-rtree

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "**********************"
    echo "Failed to configure Sqlite3"
    echo "**********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to build Sqlite3"
    echo "**********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to test Sqlite3"
    echo "**********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$SQLITE_TAR" "$SQLITE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
