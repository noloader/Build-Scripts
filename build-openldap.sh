#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenLDAP from sources.

LDAP_VER=2.4.58
LDAP_TAR="openldap-${LDAP_VER}.tgz"
LDAP_DIR="openldap-${LDAP_VER}"
PKG_NAME=openldap

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

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

###############################################################################

if [[ "$IS_ALPINE" -ne 0 ]] && [[ -z "$(command -v soelim 2>/dev/null)" ]]
then
    if ! ./build-mandoc.sh
    then
        echo "Failed to build Mandoc"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== OpenLDAP ==============="
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

if ! "$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" -O "$LDAP_TAR" \
     "https://gpl.savoirfairelinux.net/pub/mirrors/openldap/openldap-release/$LDAP_TAR"
then
    echo "Failed to download OpenLDAP"
    exit 1
fi

rm -rf "$LDAP_DIR" &>/dev/null
gzip -d < "$LDAP_TAR" | tar xf -
cd "$LDAP_DIR" || exit 1

if [[ -e ../patch/openldap.patch ]]; then
    echo ""
    echo "****************************"
    echo "Patching package"
    echo "****************************"

    patch -u -p0 < ../patch/openldap.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "****************************"
echo "Configuring package"
echo "****************************"

# Fix Berkeley DB version test
cp -p configure configure.new
sed 's|0x060014|0x060300|g' configure > configure.new
mv configure.new configure; chmod a+x configure

# OpenLDAP munges -Wl,-R,'$ORIGIN/../lib'. Somehow it manages
# to escape the '$ORIGIN/../lib' in single quotes. Set $ORIGIN
# to itself to workaround it.
export ORIGIN="\$ORIGIN"

# mdb is too dirty and cannot build on OS X. It is also full of
# undefined behavior. Just disable mdb on all platforms.
CONFIG_OPTS=()
CONFIG_OPTS+=("--with-tls=openssl")
CONFIG_OPTS+=("--enable-mdb=no")

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
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "****************************"
    echo "Failed to configure OpenLDAP"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "****************************"
echo "Building package"
echo "****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build OpenLDAP"
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

# Can't pass self tests on ARM
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to test OpenLDAP"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    # exit 1

    echo ""
    echo "****************************"
    echo "Installing anyways..."
    echo "****************************"
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "****************************"
echo "Installing package"
echo "****************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################


# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$LDAP_TAR" "$LDAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
