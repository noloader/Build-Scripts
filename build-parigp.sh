#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PARI/GP from sources.

PARI_VER=2.13.0
PARI_TAR=pari-${PARI_VER}.tar.gz
PARI_DIR=pari-${PARI_VER}
PKG_NAME=pari

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

if ! ./build-gzip.sh
then
    echo "Failed to build Gzip"
    exit 1
fi

###############################################################################

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

if ! ./build-parigp-data.sh
then
    echo "Failed to install PARI/GP data"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== PARI/GP ================"
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "${WGET}" -q -O "$PARI_TAR" --ca-certificate="${THE_CA_ZOO}" \
     "https://pari.math.u-bordeaux.fr/pub/pari/unix/$PARI_TAR"
then
    echo "Failed to download PARI/GP"
    exit 1
fi

rm -rf "$PARI_DIR" &>/dev/null
gzip -d < "$PARI_TAR" | tar xf -
cd "$PARI_DIR" || exit 1

# cp -p config/Makefile.SH config/Makefile.SH.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/parigp.patch ]]; then
     echo ""
     echo "***************************"
     echo "Patching package"
     echo "***************************"

    patch -u -p0 < ../patch/parigp.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "***************************"
echo "Configuring package"
echo "***************************"

# XXX_LIBS added to the PARI/GP build gear by parigp.patch.
# The PARI/GP build gear is blowing away our LIBS.

# TODO: add --tune to config options

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
    XXX_LIBS="${INSTX_LDLIBS}" \
./Configure \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --sysdatadir="${INSTX_LIBDIR}" \
    --with-readline="${INSTX_PREFIX}" \
    --with-readline-lib="${INSTX_LIBDIR}" \
    --with-gmp="${INSTX_PREFIX}" \
    --with-gmp-lib="${INSTX_LIBDIR}" \
    --with-qt

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***************************"
    echo "Failed to configure PARI/GP"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("gp" "-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to build PARI/GP"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Testing package"
echo "***************************"

# According to PARI/GP User manual, 'make bench' is the self tests???
# According to the mailing list, it is 'make dobench'
MAKE_FLAGS=("test-all" "-k" "-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to test PARI/GP"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Installing package"
echo "***************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

# No pkgconfig file. Make one.
{
    echo "prefix=${INSTX_PREFIX}"
    echo "exec_prefix=\${prefix}"
    echo "includedir=\${prefix}/include"
    echo "libdir=$INSTX_LIBDIR"

    echo ""
    echo "Name: PARI/GP"
    echo "Description: Computer algebra system"
    echo "URL: https://pari.math.u-bordeaux.fr"
    echo "Version: $PARI_VER"
    echo "Cflags: -I\${includedir}"
    echo "Libs: -L\${libdir} -lpari"

} > ./libpari.pc

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Install the pc file
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "./libpari.pc" "${INSTX_PKGCONFIG}"
else
    cp "./libpari.pc" "${INSTX_PKGCONFIG}"
fi

# Fix permissions once
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
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
    ARTIFACTS=("$PARI_TAR" "$PARI_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
