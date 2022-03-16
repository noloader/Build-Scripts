#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds APG from sources. APG is treated
# like a library rather then a program to avoid rebuilding
# it in other recipes like Curl and Wget.

APG_VER=2.2.3
APG_TAR="v${APG_VER}.tar.gz"
APG_DIR="apg-${APG_VER}"
PKG_NAME=apg

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
echo "================= APG ================="
echo "========================================"

echo ""
echo "***********************"
echo "Downloading package"
echo "***********************"

echo ""
echo "libapg ${APG_VER}..."

if ! "$WGET" -q -O "$APG_TAR" --ca-certificate="$GITHUB_CA_ZOO" \
     "https://github.com/jabenninghoff/apg/archive/$APG_TAR"
then
    echo "Failed to download APG"
    exit 1
fi

rm -rf "$APG_DIR" &>/dev/null
gzip -d < "$APG_TAR" | tar xf -
cd "$APG_DIR" || exit 1

#cp Makefile Makefile.orig
#cp apg.c apg.c.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/apg.patch ]]; then
    echo ""
    echo "***********************"
    echo "Patching package"
    echo "***********************"

    patch -u -p0 < ../patch/apg.patch
fi

echo ""
echo "***********************"
echo "Building package"
echo "***********************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LDLIBS="${INSTX_LDLIBS}"
LIBS="${INSTX_LDLIBS}"

if [[ "$IS_LINUX" -ne 0 ]]; then
    LIBS="-lcrypt ${LIBS}"
fi

MAKE_FLAGS=("standalone" "-j" "${INSTX_JOBS}")
if ! CPPFLAGS="${CPPFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***********************"
    echo "Failed to configure APG"
    echo "***********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Testing package"
echo "***********************"

echo ""
echo "***********************"
echo "Package not tested"
echo "***********************"

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Installing anyways..."
echo "***********************"

MAKE_FLAGS=("install" "APG_PREFIX=${INSTX_PREFIX}")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
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
    ARTIFACTS=("$APG_TAR" "$APG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
