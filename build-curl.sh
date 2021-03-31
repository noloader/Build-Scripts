#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

CURL_VER=7.76.0
CURL_TAR="curl-${CURL_VER}.tar.gz"
CURL_DIR="curl-${CURL_VER}"
PKG_NAME=curl

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
    echo "Failed to install CA certs"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

# Needs real C++14 support
if [[ "$INSTX_CXX14" -eq 1 ]]
then
    if ! ./build-nghttp2.sh
    then
        echo "Failed to build NGHTTP2"
        exit 1
    fi
fi

###############################################################################

if ! ./build-openldap.sh
then
    echo "Failed to build OpenLDAP"
    exit 1
fi

###############################################################################

# PSL may be skipped if Python is too old. libpsl requires Python 2.7
# Also see https://stackoverflow.com/a/40950971/608639
if [[ -n "$(command -v python 2>/dev/null)" ]]
then
    ver=$(python -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
    if [ "$ver" -ge 27 ]
    then
        if ! ./build-libpsl.sh
        then
            echo "Failed to build Public Suffix List library"
            exit 1
        fi
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================ cURL =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CURL_TAR" --ca-certificate="$THE_CA_ZOO" \
     "https://curl.se/download/$CURL_TAR"
then
    echo "Failed to download cURL"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$CURL_DIR" &>/dev/null
gzip -d < "$CURL_TAR" | tar xf -
cd "$CURL_DIR" || exit 1

if [[ -e ../patch/curl.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/curl.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    curl_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CURL_DIR}"
    curl_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${CURL_DIR}"
else
    curl_cflags="${INSTX_CFLAGS}"
    curl_cxxflags="${INSTX_CXXFLAGS}"
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-optimize")
CONFIG_OPTS+=("--enable-symbol-hiding")
CONFIG_OPTS+=("--enable-http")
CONFIG_OPTS+=("--enable-ftp")
CONFIG_OPTS+=("--enable-file")
CONFIG_OPTS+=("--enable-ldap")
CONFIG_OPTS+=("--enable-ldaps")
CONFIG_OPTS+=("--enable-rtsp")
CONFIG_OPTS+=("--enable-proxy")
CONFIG_OPTS+=("--enable-dict")
CONFIG_OPTS+=("--enable-telnet")
CONFIG_OPTS+=("--enable-tftp")
CONFIG_OPTS+=("--enable-pop3")
CONFIG_OPTS+=("--enable-imap")
CONFIG_OPTS+=("--enable-smb")
CONFIG_OPTS+=("--enable-smtp")
CONFIG_OPTS+=("--enable-gopher")
CONFIG_OPTS+=("--enable-cookies")
CONFIG_OPTS+=("--enable-ipv6")
CONFIG_OPTS+=("--with-zlib=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-ssl=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libidn2=${INSTX_PREFIX}")
CONFIG_OPTS+=("--without-gnutls")
CONFIG_OPTS+=("--without-polarssl")
CONFIG_OPTS+=("--without-mbedtls")
CONFIG_OPTS+=("--without-cyassl")
CONFIG_OPTS+=("--without-nss")
CONFIG_OPTS+=("--without-libssh2")
CONFIG_OPTS+=("--with-ca-bundle=$INSTX_CACERT_FILE")

if [[ "$INSTX_CXX14" -eq 1 ]]; then
    CONFIG_OPTS+=("--with-nghttp2")
else
    CONFIG_OPTS+=("--without-nghttp2")
fi

# OpenSSL 1.1.x does not have RAND_egd, but curl lacks --without-egd
# We also want to disable the SSLv2 code paths. Hack it by providing
# ac_cv_func_RAND_egd=no and ac_cv_func_SSLv2_client_method=no.

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${curl_cflags}" \
    CXXFLAGS="${curl_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    ac_cv_func_RAND_egd=no \
    ac_cv_func_SSLv2_client_method=no \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]
then
    echo ""
    echo "************************"
    echo "Failed to configure cURL"
    echo "************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to build cURL"
    echo "************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo ""
echo "**********************"
echo "Testing package"
echo "**********************"

# Disable Valgrind with "TFLAGS=-n". Too many findings due
# to -march=native. We also want the sanitizers since others
# are doing the Valgrind testing.
MAKE_FLAGS=("test" "TFLAGS=-n" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "************************"
    echo "Failed to test cURL"
    echo "************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    #exit 1

    echo ""
    echo "**********************"
    echo "Installing anyways..."
    echo "************************"
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${CURL_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${CURL_DIR}"
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
    ARTIFACTS=("$CURL_TAR" "$CURL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
