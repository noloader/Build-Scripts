#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds HFS+ Tools from sources.

HFSPLUSTOOLS_VER=master
HFSPLUSTOOLS_DIR=hsfplustools-${HFSPLUSTOOLS_VER}
PKG_NAME=hsfplustools

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

echo ""
echo "========================================"
echo "============== HFS+ Tools =============="
echo "========================================"

echo ""
echo "HFS+ Tools ${HFSPLUSTOOLS_VER}..."

rm -rf "$HFSPLUSTOOLS_DIR" 2>/dev/null

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

if ! git clone --depth=3 https://github.com/miniupnp/hfsplustools.git "$HFSPLUSTOOLS_DIR";
then
    echo "Failed to checkout HFS+ Tools"
    exit 1
fi

cd "$HFSPLUSTOOLS_DIR"
git checkout master &>/dev/null

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
export CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
export ASFLAGS=$(echo "${INSTX_ASFLAGS}" | sed 's/\$/\$\$/g')
export CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
export CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
export LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
export LIBS="${INSTX_LDLIBS}"

export PREFIX="${INSTX_PREFIX}"
export LIBDIR="${INSTX_LIBDIR}"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build HFS+ Tools"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

#echo ""
#echo "**********************"
#echo "Testing package"
#echo "**********************"

# Man, Valgirnd is awful when it comes to trying to build self tests.
# MAKE_FLAGS=("check" "-k" "V=1")
# if ! "${MAKE}" "${MAKE_FLAGS[@]}"
# then
#    echo "Failed to test HFS+ Tools"
#    exit 1
# fi

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
    ARTIFACTS=("$HFSPLUSTOOLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
