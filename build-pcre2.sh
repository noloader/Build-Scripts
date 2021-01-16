#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PCRE from sources.

PCRE2_VER=10.36
PCRE2_TAR="pcre2-${PCRE2_VER}.tar.gz"
PCRE2_DIR="pcre2-${PCRE2_VER}"
PKG_NAME=pcre2

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
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

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= PCRE2 ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "PCRE2 ${PCRE2_VER}..."

if ! "$WGET" -q -O "$PCRE2_TAR" --ca-certificate="$IDENTRUST_ROOT" \
     "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR"
then
    echo "Failed to download PCRE2"
    exit 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    pcre2_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${PCRE2_DIR}"
    pcre2_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${PCRE2_DIR}"
else
    pcre2_cflags="${INSTX_CFLAGS}"
    pcre2_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${pcre2_cflags}" \
    CXXFLAGS="${pcre2_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-static \
    --enable-shared \
    --enable-pcre2-8 \
    --enable-pcre2-16 \
    --enable-pcre2-32

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PCRE2"
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
    echo "**********************"
    echo "Failed to build PCRE2"
    echo "**********************"
    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# PCRE2 fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
if [[ "$IS_LINUX" -ne 0 ]]; then
    MAKE_FLAGS=("check" "-k" "V=1")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "**********************"
        echo "Failed to test pcre2"
        echo "**********************"
        bash ../collect-logs.sh "${PKG_NAME}"
        # exit 1
    fi
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
        printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${PCRE2_DIR}"
    fi
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${PCRE2_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$PCRE2_TAR" "$PCRE2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
