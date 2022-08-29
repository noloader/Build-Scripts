#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Nginx from sources.

NGINX_VER=1.20.2
NGINX_TAR=nginx-${NGINX_VER}.tar.gz
NGINX_DIR=nginx-${NGINX_VER}
PKG_NAME=nginx

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-pcre.sh
then
    echo "Failed to build PCRE"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Nginx ================="
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

echo ""
echo "Nginx ${NGINX_VER}..."

if ! "${WGET}" -q -O "$NGINX_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://nginx.org/download/$NGINX_TAR"
then
    echo "Failed to download Nginx"
    exit 1
fi

rm -rf "$NGINX_DIR" &>/dev/null
gzip -d < "$NGINX_TAR" | tar xf -
cd "$NGINX_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/nginx.patch ]]; then
    echo ""
    echo "****************************"
    echo "Patching package"
    echo "****************************"

    patch -u -p0 < ../patch/nginx.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "****************************"
echo "Configuring package"
echo "****************************"

# Nginx is another package that f**ks up flags and options. There's nothing
# like trading something that works for something that does not work.
# http://nginx.org/en/docs/configure.html

nginx_cppflags="${INSTX_CPPFLAGS} -I${INSTX_PREFIX}/include"
nginx_cflags="${INSTX_CFLAGS}"
nginx_cxxflags="${INSTX_CXXFLAGS}"
nginx_ldflags="${INSTX_LDFLAGS} -L${INSTX_LIBDIR}"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${nginx_cppflags}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${nginx_cflags}" \
    CXXFLAGS="${nginx_cxxflags}" \
    LDFLAGS="${nginx_ldflags}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --with-cc-opt="${nginx_cppflags} ${nginx_cflags}" \
    --with-ld-opt="${nginx_ldflags}" \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_sub_module \
    --with-http_auth_request_module

    # --with-pcre="${INSTX_PREFIX}" \
    # --with-zlib="${INSTX_PREFIX}" \
    # --with-openssl="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "****************************"
    echo "Failed to configure Nginx"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "****************************"
echo "Building package"
echo "****************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build Nginx"
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

MAKE_FLAGS=("test")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to test Nginx"
    echo "****************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    # exit 1

    echo ""
    echo "****************************"
    echo "Installing anyways"
    echo "****************************"
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "****************************"
echo "Installing package"
echo "****************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
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
    ARTIFACTS=("$NGINX_TAR" "$NGINX_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
