#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bison from sources.

# The Bison recipe is broken at the moment. 'make && make check' fails.
# The 'make check' recipe tries to build the documentation even when the
# tools are missing. Derp...

BISON_VER=3.7.4.254
BISON_TAR=bison-${BISON_VER}-a0905.tar.gz
BISON_DIR=bison-${BISON_VER}-a0905

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

# Autotools on Solaris is broken. Bison 3.7.1 and above fails to configure due
# to a buggy strstr(). The rub is, Bison does not use the function. WTF???
if [[ "${IS_SOLARIS}" -eq 1 ]]; then
    BISON_VER=3.7
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

if ! "$WGET" -q -O "$BISON_TAR" --ca-certificate="$CA_ZOO" \
     "https://www.lrde.epita.fr/~akim/private/bison/bison-3.7.4.254-a0905.tar.gz"
then
    echo "Failed to download Bison"
    exit 1
fi

rm -rf "$BISON_DIR" &>/dev/null
gzip -d < "$BISON_TAR" | tar xf -
cd "$BISON_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/bison-rc.patch ]]; then
    patch -u -p0 < ../patch/bison-rc.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "*************************"
echo "Configuring package"
echo "*************************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
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
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo "*************************"
    echo "Failed to configure Bison"
    echo "*************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "*************************"
echo "Building package"
echo "*************************"

MAKE_FLAGS=("MAKEINFO=true" "HELP2MAN=true" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "*************************"
    echo "Failed to build Bison"
    echo "*************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "*************************"
echo "Testing package"
echo "*************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "*************************"
    echo "Failed to test Bison"
    echo "*************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

echo "*************************"
echo "Installing package"
echo "*************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
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
