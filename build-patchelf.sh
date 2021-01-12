#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds patchelf from sources.

PATCHELF_VER=0.12
PATCHELF_TAR=${PATCHELF_VER}.tar.gz
PATCHELF_DIR=patchelf-${PATCHELF_VER}
PKG_NAME=patchelf

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

# Verify system uses ELF
#magic=$(cut -b 2-4 /bin/ls | head -n 1)
#if [[ "$magic" != "ELF" ]]; then
#    exit 0
#fi

# Patchelf only builds on Linux and HURD. Solaris is trouble.
if [[ "$IS_LINUX" -eq 0 && "$IS_HURD" -eq 0 ]]; then
    exit 0
fi

# patchelf is a program and it is supposed to be rebuilt
# on demand. However, this recipe can be called for each
# build recipe, so build it only once.
if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# patchelf needs c++11
if [[ "$INSTX_CXX11" -eq 0 ]]; then
    echo ""
    echo "$PKG_NAME needs a C++11 compiler."
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
echo "=============== Patchelf ==============="
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

if ! "$WGET" -q -O "$PATCHELF_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/NixOS/patchelf/archive/$PATCHELF_TAR"
then
    echo "****************************"
    echo "Failed to download patchelf"
    echo "****************************"
    exit 1
fi

rm -rf "$PATCHELF_DIR" &>/dev/null
gzip -d < "$PATCHELF_TAR" | tar xf -
cd "$PATCHELF_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/patchelf.patch ]]; then
    patch -u -p0 < ../patch/patchelf.patch
    echo ""
fi

if ! ./bootstrap.sh
then
    echo "****************************"
    echo "Failed to bootstrap patchelf"
    echo "****************************"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "****************************"
echo "Configuring package"
echo "****************************"

# patchelf does not have regular dependencies, like libbzip2,
# so we don't need LDFLAGS. We can omit the variable since
# our standard LDFLAGS mucks with the self tests.

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo "****************************"
    echo "Failed to configure patchelf"
    echo "****************************"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
# bash ../fix-makefiles.sh

echo "****************************"
echo "Building package"
echo "****************************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "****************************"
    echo "Failed to build patchelf"
    echo "****************************"
    exit 1
fi

# Fix flags in *.pc files
# bash ../fix-pkgconfig.sh

echo "****************************"
echo "Testing package"
echo "****************************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "****************************"
    echo "Failed to test patchelf"
    echo "****************************"
    # exit 1
fi

echo "****************************"
echo "Installing package"
echo "****************************"

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

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$PATCHELF_TAR" "$PATCHELF_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
