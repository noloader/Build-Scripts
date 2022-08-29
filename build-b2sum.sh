#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds b2sum from sources.

B2SUM_VER=20190724
B2SUM_TAR=${B2SUM_VER}.tar.gz
B2SUM_DIR=BLAKE2-${B2SUM_VER}
PKG_NAME=blake2

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

# BLAKE2 only has benchmarks for Intel machines
if [ "$IS_IA32" -ne 0 ]
then
    if ! ./build-openssl.sh
    then
        echo "Failed to build OpenSSL"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================= b2sum ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "b2sum ${B2SUM_VER}..."

if ! "${WGET}" -q -O "$B2SUM_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/BLAKE2/BLAKE2/archive/$B2SUM_TAR"
then
    echo "Failed to download b2sum"
    exit 1
fi

rm -rf "$B2SUM_DIR" &>/dev/null
gzip -d < "$B2SUM_TAR" | tar xf -
cd "$B2SUM_DIR"

if [[ -e ../patch/b2sum.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/b2sum.patch
    echo ""
fi

# The Makefiles needed so much work it was easier to provide Autotools for them.
# The files were offered to BLAKE2 at https://github.com/BLAKE2/BLAKE2/pull/63.
if [[ -e ../patch/b2sum-autotools.zip ]]; then
    cp ../patch/b2sum-autotools.zip .
    unzip -oq b2sum-autotools.zip
fi

echo "**********************"
echo "Bootstrapping package"
echo "**********************"

if ! autoreconf --install --force 1>/dev/null
then
    echo "***************************"
    echo "Failed to bootstrap package"
    echo "***************************"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure b2sum"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile" "V=1")
MAKE_FLAGS+=("-j" "${INSTX_JOBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build b2sum"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test b2sum"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=${INSTX_PREFIX}")
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
    ARTIFACTS=("$B2SUM_TAR" "$B2SUM_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
