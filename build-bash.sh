#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bash from sources.

BASH_VER=5.1
BASH_TAR="bash-${BASH_VER}.tar.gz"
BASH_DIR="bash-${BASH_VER}"
PKG_NAME=bash

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

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Bash ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Bash ${BASH_VER}..."

if ! "$WGET" -q -O "$BASH_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/bash/$BASH_TAR"
then
    echo "Failed to download Bash"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$BASH_DIR" &>/dev/null
gzip -d < "$BASH_TAR" | tar xf -
cd "$BASH_DIR"

if [[ -e ../patch/bash.patch ]]; then
    patch -u -p0 < ../patch/bash.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Bash has lots of other options. We should use what a distro provides.
# TODO: figure out what a distro like Debian or Red Hat provides ...
# https://www.gnu.org/software/bash/manual/html_node/Optional-Features.html

BASH_CFLAGS="${INSTX_CFLAGS}"
BASH_CXXFLAGS="${INSTX_CXXFLAGS}"

if [[ -n "$opt_debug_prefix_map" ]]; then
    BASH_CFLAGS="${BASH_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${BASH_DIR}"
    BASH_CXXFLAGS="${BASH_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${BASH_DIR}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${BASH_CFLAGS}" \
    CXXFLAGS="${BASH_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="-ltinfow ${INSTX_LDLIBS}" \
    LIBS="-ltinfow ${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --with-curses --enable-multibyte \
    --with-installed-readline="${INSTX_PREFIX}" \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Bash"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bash"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# MAKE_FLAGS=("PERL_USE_UNSAFE_INC=1" "check")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Bash"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    if [[ -n "$opt_debug_prefix_map" ]]; then
        printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy_sources.sh "${PWD}" "${INSTX_SRCDIR}/${BASH_DIR}"
    fi
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    if [[ -n "$opt_debug_prefix_map" ]]; then
        bash ../copy_sources.sh "${PWD}" "${INSTX_SRCDIR}/${BASH_DIR}"
    fi
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
    ARTIFACTS=("$BASH_TAR" "$BASH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
