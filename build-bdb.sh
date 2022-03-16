#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Berkeley DB from sources.

# Note: we do not build with OpenSSL. There is a circular
# dependency between Berkeley DB, OpenSSL and Perl.
# The loss of SSL/TLS in Berkeley DB means the Replication
# Manager does not have SSL/TLS support.

BDB_VER=6.2.32
BDB_TAR=db-${BDB_VER}.tar.gz
BDB_DIR=db-${BDB_VER}
PKG_NAME=bdb

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
echo "============== Berkeley DB ============="
echo "========================================"

echo ""
echo "Berkeley DB ${BDB_VER}..."

echo ""
echo "*******************************"
echo "Copying package"
echo "*******************************"

cp "bootstrap/$BDB_TAR" "$PWD"
rm -rf "$BDB_DIR" &>/dev/null
gzip -d < "$BDB_TAR" | tar xf -

cd "$BDB_DIR" || exit 1

if [[ -e ../patch/db.patch ]]; then
    echo ""
    echo "*******************************"
    echo "Patching package"
    echo "*******************************"

    patch -u -p0 < ../patch/db.patch
fi

cd "${CURR_DIR}" || exit 1
cd "$BDB_DIR/dist" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

cd "${CURR_DIR}" || exit 1
cd "$BDB_DIR" || exit 1

echo ""
echo "*******************************"
echo "Configuring package"
echo "*******************************"

CONFIG_OPTS=()
if [[ "${INSTX_CXX11_ATOMIC}" -eq 1 ]];then
    CONFIG_OPTS+=("--enable-cxx")
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./dist/configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --with-tls=openssl \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "*******************************"
    echo "Failed to configure Berkeley DB"
    echo "*******************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "*******************************"
echo "Building package"
echo "*******************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "*******************************"
    echo "Failed to build Berkeley DB"
    echo "*******************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*******************************"
echo "Testing package"
echo "*******************************"

echo ""
echo "*******************************"
echo "Unable to test Berkeley DB"
echo "*******************************"

# No check or test recipes
#MAKE_FLAGS=("check" "-k" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "*******************************"
#    echo "Failed to test Berkeley DB"
#    echo "*******************************"
#
#    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
#    exit 1
#fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "*******************************"
echo "Installing anyways..."
echo "*******************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

# Write the *.pc file
{
    echo ""
    echo "prefix=${INSTX_PREFIX}"
    echo "exec_prefix=\${prefix}"
    echo "libdir=${INSTX_LIBDIR}"
    echo "sharedlibdir=\${libdir}"
    echo "includedir=\${prefix}/include"
    echo ""
    echo "Name: Berkeley DB"
    echo "Description: Berkeley DB client library"
    echo "Version: 6.2"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -ldb"
    echo "Cflags: -I\${includedir}"
} > libdb.pc

# Install the pc file
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S cp "./libdb.pc" "${INSTX_PKGCONFIG}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S chmod u=rw,go=r "${INSTX_PKGCONFIG}/libdb.pc"
else
    cp "./libdb.pc" "${INSTX_PKGCONFIG}"
    chmod u=rw,go=r "${INSTX_PKGCONFIG}/libdb.pc"
fi

# Fix permissions once
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$BDB_TAR" "$BDB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
