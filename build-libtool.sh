#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Libtool from sources.

LIBTOOL_TAR=libtool-2.4.6.tar.gz
LIBTOOL_DIR=libtool-2.4.6
PKG_NAME=libtool

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

echo ""
echo "========================================"
echo "================ libtool ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "${WGET}" -q -O "$LIBTOOL_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://ftp.gnu.org/gnu/libtool/$LIBTOOL_TAR"
then
    echo "Failed to download libtool and libltdl"
    exit 1
fi

rm -rf "$LIBTOOL_DIR" &>/dev/null
gzip -d < "$LIBTOOL_TAR" | tar xf -
cd "$LIBTOOL_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-ltdl-install")

if [[ "$IS_DARWIN" -ne 0 ]]; then
    CONFIG_OPTS+=("--program-prefix=g")
fi

CONFIG_LIBTOOL=$(command -v glibtool 2>/dev/null)
if [[ -z "$CONFIG_LIBTOOL" ]]; then
    CONFIG_LIBTOOL=$(command -v libtool 2>/dev/null)
fi

CONFIG_M4=$(command -v m4 2>/dev/null)
if [[ -e "${INSTX_PREFIX}/bin/m4" ]]; then
    CONFIG_M4="${INSTX_PREFIX}/bin/m4"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
    M4="${CONFIG_M4}" \
    LIBTOOL="${CONFIG_LIBTOOL}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libtool and libltdl"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libtool and libltdl"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# https://lists.gnu.org/archive/html/bug-libtool/2017-10/msg00009.html
# MAKE_FLAGS=("check" "-k" "V=1")
# if ! "${MAKE}" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test libtool and libltdl"
#     exit 1
# fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

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
    ARTIFACTS=("$LIBTOOL_TAR" "$LIBTOOL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
