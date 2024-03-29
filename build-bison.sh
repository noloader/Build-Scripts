#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bison from sources.

# The Bison recipe is broken at the moment. 'make && make check' fails.
# The 'make check' recipe tries to build the documentation even when the
# tools are missing. Derp...

BISON_VER=3.8.2
BISON_TAR=bison-${BISON_VER}.tar.gz
BISON_DIR=bison-${BISON_VER}
PKG_NAME=bison

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

# Autotools on Solaris is broken. Bison 3.7.1 and above fails to configure due
# to a buggy strstr(). The rub is, Bison does not use the function. WTF???
if [[ "${IS_SOLARIS}" -eq 1 ]]; then
    BISON_VER=3.7
    BISON_TAR=bison-${BISON_VER}.tar.gz
    BISON_DIR=bison-${BISON_VER}
fi

# Bison 3.0, and 3.2 through 3.7 fail to compile on OS X 10.5.
# https://lists.gnu.org/archive/html/bug-bison/2021-03/msg00005.html
if [[ "${OSX_10p5_OR_BELOW}" -eq 1 ]]; then
    BISON_VER=3.1
    BISON_TAR=bison-${BISON_VER}.tar.gz
    BISON_DIR=bison-${BISON_VER}
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

echo ""
echo "========================================"
echo "================= Bison ================"
echo "========================================"

echo ""
echo "*************************"
echo "Downloading package"
echo "*************************"

echo ""
echo "Bison ${BISON_VER}..."

if ! "${WGET}" -q -O "$BISON_TAR" --ca-certificate="${THE_CA_ZOO}" \
     "https://ftp.gnu.org/gnu/bison/$BISON_TAR"
then
    echo "Failed to download Bison"
    exit 1
fi

rm -rf "$BISON_DIR" &>/dev/null
gzip -d < "$BISON_TAR" | tar xf -
cd "$BISON_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/bison.patch ]]; then
    echo ""
    echo "*************************"
    echo "Patching package"
    echo "*************************"

    patch -u -p0 < ../patch/bison.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "*************************"
echo "Configuring package"
echo "*************************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    bison_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${BISON_DIR}"
    bison_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${BISON_DIR}"
else
    bison_cflags="${INSTX_CFLAGS}"
    bison_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${bison_cflags}" \
    CXXFLAGS="${bison_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}" \
    --with-libreadline-prefix="${INSTX_PREFIX}" \
    --with-libtextstyle-prefix="${INSTX_PREFIX}" \
    --disable-assert

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "*************************"
    echo "Failed to configure Bison"
    echo "*************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "*************************"
echo "Building package"
echo "*************************"

MAKE_FLAGS=("MAKEINFO=true" "HELP2MAN=true" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*************************"
    echo "Failed to build Bison"
    echo "*************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*************************"
echo "Testing package"
echo "*************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*************************"
    echo "Failed to test Bison"
    echo "*************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*************************"
echo "Installing package"
echo "*************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${BISON_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${BISON_DIR}"
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
    ARTIFACTS=("$BISON_TAR" "$BISON_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
