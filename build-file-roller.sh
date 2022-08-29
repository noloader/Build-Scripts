#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds File Roller from sources.

FROLLER_TAR=file-roller-3.36.3.tar.gz
FROLLER_DIR=file-roller-3.36.3
PKG_NAME=file-roller

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
echo "============== File Roller ============="
echo "========================================"

echo ""
echo "**************************"
echo "Downloading package"
echo "**************************"

if ! "${WGET}" -q -O "$FROLLER_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://gitlab.gnome.org/GNOME/file-roller/-/archive/3.36.3/$FROLLER_TAR"
then
    echo "Failed to download File Roller"
    exit 1
fi

rm -rf "$FROLLER_DIR" &>/dev/null
gzip -d < "$FROLLER_TAR" | tar xf -
cd "$FROLLER_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/froller.patch ]]; then
    echo ""
    echo "**************************"
    echo "Downloading package"
    echo "**************************"

    patch -u -p0 < ../patch/froller.patch
fi

if ! mkdir build; then
    echo "Failed to create build directory"
    exit 1
fi

cd build || exit 1

export PKG_CONFIG_PATH="${INSTX_PKGCONFIG}"
export CPPFLAGS="${INSTX_CPPFLAGS}"
export ASFLAGS="${INSTX_ASFLAGS}"
export CFLAGS="${INSTX_CFLAGS}"
export CXXFLAGS="${INSTX_CXXFLAGS}"
export LDFLAGS="${INSTX_LDFLAGS}"
export LIBS="${INSTX_LDLIBS}"

if ! meson ..; then
    echo "Failed to run meson"
    exit 1
fi

if ! ninja; then
    echo "Failed to run ninja"
    exit 1
fi

if false; then

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**************************"
echo "Configuring package"
echo "**************************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure File Roller"
    exit 1
fi

fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "**************************"
echo "Building package"
echo "**************************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build File Roller"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**************************"
echo "Testing package"
echo "**************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to test File Roller"
    echo "**************************"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**************************"
echo "Installing package"
echo "**************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
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
if true; then

    ARTIFACTS=("$FROLLER_TAR" "$FROLLER_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-froller.sh 2>&1 | tee build-froller.log
    if [[ -e build-froller.log ]]; then
        rm -f build-froller.log
    fi
fi

exit 0
