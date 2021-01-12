#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GMP from sources.

GMP_VER=6.2.1
GMP_TAR="gmp-${GMP_VER}.tar.bz2"
GMP_DIR="gmp-${GMP_VER}"
PKG_NAME=gmp

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

echo ""
echo "========================================"
echo "================= GMP =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "GMP ${GMP_VER}..."

if ! "$WGET" -q -O "$GMP_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/gmp/$GMP_TAR"
then
    echo "Failed to download GMP"
    exit 1
fi

rm -rf "$GMP_DIR" &>/dev/null
bzip2 -d < "$GMP_TAR" | tar xf -
cd "$GMP_DIR" || exit 1

# Fix decades old compile and link errors on early Darwin.
# https://gmplib.org/list-archives/gmp-bugs/2009-May/001423.html
if [[ "$OSX_105_OR_BELOW" -ne 0 ]]; then
    if [[ -e ../patch/gmp-darwin.patch ]]; then
        patch -u -p0 < ../patch/gmp-darwin.patch
        echo ""
    fi
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

# Fix FreeBSD configure test
if true; then
    file=configure
    touch -a -m -r "$file" "$file.timestamp.saved"
    chmod a+w "$file"
    sed 's/__builtin_clzl//g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod a+x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp.saved" "$file"
    rm -f "$file.timestamp.saved" "$file.fixed"
fi

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-assert=no")
CONFIG_OPTS+=("ABI=$INSTX_BITNESS")

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

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GMP"
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
    echo "Failed to build GMP"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test GMP"
    echo "**********************"
    exit 1
fi

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

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GMP_TAR" "$GMP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
