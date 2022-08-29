#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Datefudge from sources.

DATEFUDGE_VER=1.24
DATEFUDGE_XZ=datefudge_${DATEFUDGE_VER}.tar.xz
DATEFUDGE_TAR=datefudge_${DATEFUDGE_VER}.tar
DATEFUDGE_DIR=datefudge-${DATEFUDGE_VER}
PKG_NAME=datefudge

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
echo "============== Datefudge ==============="
echo "========================================"

echo ""
echo "*****************************"
echo "Downloading package"
echo "*****************************"

echo ""
echo "Datefudge ${DATEFUDGE_VER}..."

if ! "${WGET}" -q -O "$DATEFUDGE_XZ" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "http://deb.debian.org/debian/pool/main/d/datefudge/$DATEFUDGE_XZ"
then
    echo "Failed to download Datefudge"
    exit 1
fi

rm -rf "$DATEFUDGE_TAR" "$DATEFUDGE_DIR" &>/dev/null
unxz "$DATEFUDGE_XZ" && tar -xf "$DATEFUDGE_TAR"
cd "$DATEFUDGE_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    if [[ -e ../patch/datefudge-solaris.patch ]]; then
        echo ""
        echo "*****************************"
        echo "Patching package"
        echo "*****************************"

        patch -u -p0 < ../patch/datefudge-solaris.patch
    fi
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "*****************************"
echo "Building package"
echo "*****************************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "${INSTX_ASFLAGS}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! CC="${CC}" \
     CPPFLAGS="${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to configure Datefudge"
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

MAKE_FLAGS=("test" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*****************************"
    echo "Failed to test Datefudge"
    echo "*****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*****************************"
echo "Installing package"
echo "*****************************"

MAKE_FLAGS=("install" "prefix=${INSTX_PREFIX}" "libdir=${INSTX_LIBDIR}")
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
    ARTIFACTS=("$DATEFUDGE_XZ" "$DATEFUDGE_TAR" "$DATEFUDGE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
