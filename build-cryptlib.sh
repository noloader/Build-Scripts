#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Cryptlib library from sources.

CRYPTLIB_VER=345
CRYPTLIB_ZIP=cryptlib${CRYPTLIB_VER}.zip
CRYPTLIB_DIR=cryptlib${CRYPTLIB_VER}
PKG_NAME=cryptlib

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
echo "============== Cryptlib ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CRYPTLIB_ZIP" --ca-certificate="$THE_CA_ZOO" \
     "https://cryptlib-release.s3-ap-southeast-1.amazonaws.com/$CRYPTLIB_ZIP"
then
    echo "Failed to download Cryptlib"
    exit 1
fi

rm -rf "$CRYPTLIB_DIR" &>/dev/null
unzip -aoq "$CRYPTLIB_ZIP" -d "$CRYPTLIB_DIR"
cd "$CRYPTLIB_DIR"

convert=$(command -v dos2unix 2>/dev/null)
IFS= find "$PWD" -name '*.sh' -print | while read -r file
do
    touch -a -m -r "$file" "$file.timestamp"
    chmod +x "$file"
    if [[ -n "${convert}" ]]; then
        ${convert} "$file" &>/dev/null
    fi
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "$INSTX_CPPFLAGS" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "$INSTX_ASFLAGS" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! CPPFLAGS="-I. ${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     XCFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Cryptlib"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("testlib" "-j" "${INSTX_JOBS}")
if ! CPPFLAGS="-I. ${CPPFLAGS}" \
     ASFLAGS="${ASFLAGS}" \
     CFLAGS="${CFLAGS}" \
     XCFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Cryptlib"
    exit 1
fi

echo "**********************"
echo "Running test"
echo "**********************"
if ! ./testlib
then
    echo "Failed to test Cryptlib"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=${INSTX_PREFIX}" "LIBDIR=${INSTX_LIBDIR}")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
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
    ARTIFACTS=("$CRYPTLIB_ZIP" "$CRYPTLIB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
