#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GDBM from sources.

GDBM_VER=1.22
GDBM_TAR=gdbm-${GDBM_VER}.tar.gz
GDBM_DIR=gdbm-${GDBM_VER}
PKG_NAME=gdbm

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

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

if [[ ! -f "${INSTX_PREFIX}/bin/bison" ]]
then
    if ! ./build-bison.sh
    then
        echo "Failed to build Bison"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================= GDBM ================="
echo "========================================"

echo ""
echo "************************"
echo "Downloading package"
echo "************************"

echo ""
echo "GDBM ${GDBM_VER}..."

if ! "$WGET" -q -O "$GDBM_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/gdbm/$GDBM_TAR"
then
    echo "Failed to download GDBM"
    exit 1
fi

rm -rf "$GDBM_DIR" &>/dev/null
gzip -d < "$GDBM_TAR" | tar xf -
cd "$GDBM_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/gdbm.patch ]]; then
    echo ""
    echo "************************"
    echo "Patching package"
    echo "************************"

    patch -u -p0 < ../patch/gdbm.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "************************"
echo "Configuring package"
echo "************************"

# Should we add --enable-libgdbm-compat?
# https://www.gnu.org.ua/software/gdbm/manual/Compatibility.html

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS} -D_GNU_SOURCE" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-shared \
    --enable-static \
    --enable-libgdbm-compat \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}" \
    --with-readline-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "************************"
    echo "Failed to configure GDBM"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "************************"
echo "Building package"
echo "************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to build GDBM"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
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

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to test GDBM"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
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
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

# No pkgconfig file. Make one.
{
    echo "prefix=${INSTX_PREFIX}"
    echo "exec_prefix=\${prefix}"
    echo "includedir=\${prefix}/include"
    echo "libdir=${INSTX_LIBDIR}"

    echo ""
    echo "Name: GNU dbm library"
    echo "Description: Database functions similar to UNIX dbm"
    echo "URL: https://www.gnu.org.ua/software/gdbm/"
    echo "Documentation: https://www.gnu.org.ua/software/gdbm/manual/index.html"
    echo "Version: ${GDBM_VER}"
    echo "Cflags: -I\${includedir}"
    echo "Libs: -L\${libdir} -lgdbm"

} > ./libgdbm.pc

{
    echo "prefix=${INSTX_PREFIX}"
    echo "exec_prefix=\${prefix}"
    echo "includedir=\${prefix}/include"
    echo "libdir=${INSTX_LIBDIR}"

    echo ""
    echo "Name: GNU dbm compatibility library"
    echo "Description: Database functions for UNIX dbm and ndbm"
    echo "URL: https://www.gnu.org.ua/software/gdbm/"
    echo "Documentation: https://www.gnu.org.ua/software/gdbm/manual/index.html"
    echo "Version: ${GDBM_VER}"
    echo "Cflags: -I\${includedir}"
    echo "Libs: -L\${libdir} -lgdbm_compat"

} > ./libgdbm_compat.pc

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Install the pc file
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "./libgdbm.pc" "${INSTX_PKGCONFIG}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "./libgdbm_compat.pc" "${INSTX_PKGCONFIG}"
else
    cp "./libgdbm.pc" "${INSTX_PKGCONFIG}"
    cp "./libgdbm_compat.pc" "${INSTX_PKGCONFIG}"
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
    ARTIFACTS=("$GDBM_TAR" "$GDBM_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
