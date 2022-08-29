#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ecgen library from sources.

ECGEN_VER=0.7.3
ECGEN_TAR=${ECGEN_VER}.tar.gz
ECGEN_DIR=ecgen-${ECGEN_VER}
PKG_NAME=ecgen

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

if ! ./build-parigp.sh
then
    echo "Failed to build PARI/GP"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= ecgen ================"
echo "========================================"

echo ""
echo "************************"
echo "Downloading package"
echo "************************"

if ! "${WGET}" -q -O "$ECGEN_TAR" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/J08nY/ecgen/archive/refs/tags/$ECGEN_TAR"
then
    echo "Failed to download ecgen"
    exit 1
fi

rm -rf "$ECGEN_DIR" &>/dev/null
gzip -d < "$ECGEN_TAR" | tar xf -
cd "$ECGEN_DIR" || exit 1

if [[ -e ../patch/ecgen.patch ]]; then
    echo ""
    echo "*************************"
    echo "Patching package"
    echo "*************************"

    patch -u -p0 < ../patch/ecgen.patch
fi

# find . -type f -name '*.sh' -exec dos2unix {} \;

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    ecgen_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${ECGEN_DIR}"
    ecgen_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${ECGEN_DIR}"
else
    ecgen_cflags="${INSTX_CFLAGS}"
    ecgen_cxxflags="${INSTX_CXXFLAGS}"
fi

echo ""
echo "************************"
echo "Building package"
echo "************************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "$INSTX_CPPFLAGS" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "$INSTX_ASFLAGS" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${ecgen_cflags}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${ecgen_cxxflags}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("all" "-j" "${INSTX_JOBS}")
if ! CPPFLAGS="${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to build ecgen"
    echo "************************"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "************************"
echo "Testing package"
echo "************************"

MAKE_FLAGS=("test")
if ! CPPFLAGS="${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to test ecgen"
    echo "************************"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "************************"
echo "Installing package"
echo "************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${ECGEN_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${ECGEN_DIR}"
fi

cd "${CURR_DIR}" || exit 1

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
    ARTIFACTS=("$ECGEN_TAR" "$ECGEN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
