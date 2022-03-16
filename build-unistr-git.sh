#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Unistring from sources.

UNISTR_DIR=libunistring-master
PKG_NAME=unistring-git

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -z "$(command -v makeinfo 2>/dev/null)" ]]; then
    echo "Please install makeinfo or texinfo package."
    exit 1
fi

if [[ -e "${INSTX_PKG_CACHE}/${PKG_NAME}" ]]; then
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

# libunistring only needs iConvert

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== Unistring =============="
echo "========================================"

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

rm -rf "$UNISTR_DIR" &>/dev/null

if ! git clone https://git.savannah.gnu.org/git/libunistring.git "${UNISTR_DIR}";
then
    echo "Failed to clone patch"
    exit 1
fi

cd "$UNISTR_DIR" || exit 1

if [[ -e ../patch/unistring-git.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/unistring-git.patch
fi

echo ""
echo "**********************"
echo "Bootstrapping package"
echo "**********************"

if ! ./gitsub.sh pull;
then
    echo ""
    echo "*****************************"
    echo "Failed to bootstrap Unistring"
    echo "*****************************"

    exit 1
fi

if ! ./autogen.sh;
then
    echo ""
    echo "*****************************"
    echo "Failed to bootstrap Unistring"
    echo "*****************************"

    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

# https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/1340250
if [[ -n "$opt_no_as_needed" ]]; then
    UNISTR_LDFLAGS="$opt_no_as_needed"
else
    UNISTR_LDFLAGS=""
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS} ${UNISTR_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static --enable-shared \
    --enable-threads \
    --with-libiconv-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "*****************************"
    echo "Failed to configure Unistring"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "*****************************"
echo "Building package"
echo "*****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to build Unistring"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*****************************"
echo "Testing package"
echo "*****************************"

# Unistring fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
# https://lists.gnu.org/archive/html/bug-libunistring/2021-01/msg00000.html
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to test Unistring"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    # exit 1

    echo ""
    echo "*****************************"
    echo "Installing anyways..."
    echo "*****************************"
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*****************************"
echo "Installing package"
echo "*****************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$UNISTR_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
