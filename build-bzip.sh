#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# shellcheck disable=SC2191

# Bzip lost its website. It is now located on Sourceware.

BZIP2_VER=1.0.8
BZIP2_TAR=bzip2-${BZIP2_VER}.tar.gz
BZIP2_DIR=bzip2-${BZIP2_VER}
PKG_NAME=bzip2

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

# Needed to unpack the new Makefiles
if [[ -z "$(command -v unzip 2>/dev/null)" ]]; then
    echo ""
    echo "Please install unzip command."
    exit 1
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
echo "================= Bzip2 ================"
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

echo ""
echo "Bzip2 ${BZIP2_VER}..."

if ! "$WGET" -q -O "$BZIP2_TAR" \
     "ftp://sourceware.org/pub/bzip2/$BZIP2_TAR"
then
    echo "Failed to download Bzip"
    exit 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR" || exit 1

# The Makefiles needed so much work it was easier to rewrite them.
if [[ -e ../patch/bzip-makefiles.zip ]]; then
    echo ""
    echo "****************************"
    echo "Updating makefiles"
    echo "****************************"

    cp ../patch/bzip-makefiles.zip .
    unzip -oq bzip-makefiles.zip
fi

# Now, patch them for this script.
if [[ -e ../patch/bzip.patch ]]; then
    echo ""
    echo "****************************"
    echo "Patching package"
    echo "****************************"

    patch -u -p0 < ../patch/bzip.patch
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "****************************"
echo "Building package"
echo "****************************"

# Since we call the makefile directly, we need to escape dollar signs.
PKG_CONFIG_PATH="${INSTX_PKGCONFIG}"
CPPFLAGS=$(echo "${INSTX_CPPFLAGS}" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "${INSTX_ASFLAGS}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS}" | sed 's/\$/\$\$/g')
LDLIBS="${INSTX_LDLIBS}"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile")
MAKE_FLAGS+=("-j" "${INSTX_JOBS}")
MAKE_FLAGS+=("CC=${CC}")
MAKE_FLAGS+=("CPPFLAGS=${CPPFLAGS} -I.")
MAKE_FLAGS+=("ASFLAGS=${ASFLAGS}")
MAKE_FLAGS+=("CFLAGS=${CFLAGS}")
MAKE_FLAGS+=("CXXFLAGS=${CXXFLAGS}")
MAKE_FLAGS+=("LDFLAGS=${LDFLAGS}")
MAKE_FLAGS+=("LIBS=${LDLIBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build Bzip archive"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "****************************"
echo "Testing package"
echo "****************************"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile" "check")
MAKE_FLAGS+=("-j" "${INSTX_JOBS}")
MAKE_FLAGS+=("CC=${CC}")
MAKE_FLAGS+=("CPPFLAGS=${CPPFLAGS} -I.")
MAKE_FLAGS+=("ASFLAGS=${ASFLAGS}")
MAKE_FLAGS+=("CFLAGS=${CFLAGS}")
MAKE_FLAGS+=("CXXFLAGS=${CXXFLAGS}")
MAKE_FLAGS+=("LDFLAGS=${LDFLAGS}")
MAKE_FLAGS+=("LIBS=${LDLIBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to test Bzip"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "****************************"
echo "Installing package"
echo "****************************"

if [[ -n "$SUDO_PASSWORD" ]]
then
    echo "Installing static archive..."
    MAKE_FLAGS=("-f" "Makefile" installdirs
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "Makefile" install
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    echo "Installing static archive..."
    MAKE_FLAGS=("-f" "Makefile" installdirs
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    "${MAKE}" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "Makefile" install
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

# Clean old artifacts
"${MAKE}" clean 2>/dev/null

###############################################################################

echo ""
echo "****************************"
echo "Building package"
echo "****************************"

if [[ "$IS_DARWIN" -ne 0 ]]; then
    MAKEFILE=Makefile-libbz2_dylib
else
    MAKEFILE=Makefile-libbz2_so
fi

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "$MAKEFILE")
MAKE_FLAGS+=("-j" "${INSTX_JOBS}")
MAKE_FLAGS+=("CC=${CC}")
MAKE_FLAGS+=("CPPFLAGS=${CPPFLAGS} -I.")
MAKE_FLAGS+=("ASFLAGS=${ASFLAGS}")
MAKE_FLAGS+=("CFLAGS=${CFLAGS}")
MAKE_FLAGS+=("CXXFLAGS=${CXXFLAGS}")
MAKE_FLAGS+=("LDFLAGS=${LDFLAGS}")
MAKE_FLAGS+=("LIBS=${LDLIBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build Bzip library"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

echo ""
echo "****************************"
echo "Installing package"
echo "****************************"

if [[ -n "$SUDO_PASSWORD" ]]
then
    echo "Installing shared object..."
    MAKE_FLAGS=("-f" "$MAKEFILE" install
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "$MAKEFILE" installdirs
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    echo "Installing shared object..."
    MAKE_FLAGS=("-f" "$MAKEFILE" installdirs
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    "${MAKE}" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "$MAKEFILE" install
                PREFIX="${INSTX_PREFIX}" LIBDIR="${INSTX_LIBDIR}")
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

###############################################################################

# Write the *.pc file
{
    echo ""
    echo "prefix=${INSTX_PREFIX}"
    echo "exec_prefix=\${prefix}"
    echo "libdir=${INSTX_LIBDIR}"
    echo "sharedlibdir=\${libdir}"
    echo "includedir=\${prefix}/include"
    echo ""
    echo "Name: Bzip2"
    echo "Description: Bzip2 compression library"
    echo "Version: $BZIP2_VER"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -lbz2"
    echo "Cflags: -I\${includedir}"
} > libbz2.pc

if [[ -n "$SUDO_PASSWORD" ]]
then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S cp ./libbz2.pc "${INSTX_PKGCONFIG}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S chmod u=rw,go=r "${INSTX_PKGCONFIG}/libbz2.pc"
else
    cp ./libbz2.pc "${INSTX_PKGCONFIG}"
    chmod u=rw,go=r "${INSTX_PKGCONFIG}/libbz2.pc"
fi

# Fix permissions once
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
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
    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
