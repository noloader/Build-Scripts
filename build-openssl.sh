#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

OPENSSL_TAR=openssl-1.1.1j.tar.gz
OPENSSL_DIR=openssl-1.1.1j
PKG_NAME=openssl

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if [[ -n "$(command -v perl 2>/dev/null)" ]]; then
    PERL_MAJ=$(perl -V | head -n 1 | awk '{ print $6 }')
    PERL_MIN=$(perl -V | head -n 1 | awk '{ print $8 }')
else
    PERL_MAJ=0
    PERL_MIN=0
fi

# OpenSSL needs Perl 5.10 or above.
if [[ "$PERL_MAJ" -lt 5 || ("$PERL_MAJ" -eq 5 && "$PERL_MIN" -lt 10) ]]
then
    if ! ./build-perl.sh
    then
        echo "Failed to build Perl"
        exit 1
    fi
fi

###############################################################################

# May be skipped if Perl is too old
SKIP_OPENSSL_TESTS=0

# OpenSSL self tests
if ! perl -MTest::More -e1 2>/dev/null
then
    echo ""
    echo "OpenSSL requires Perl's Test::More. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Test-More."
    SKIP_OPENSSL_TESTS=1
fi

# OpenSSL self tests
if ! perl -MText::Template -e1 2>/dev/null
then
    echo ""
    echo "OpenSSL requires Perl's Text::Template. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Text-Template."
    SKIP_OPENSSL_TESTS=1
fi

# DH is 2x to 4x faster with ec_nistp_64_gcc_128, but it is
# only available on x64 machines with uint128 available.
INT128_OPT=$("$CC" -dM -E - </dev/null | grep -i -c "__SIZEOF_INT128__")

###############################################################################

echo ""
echo "========================================"
echo "================ OpenSSL ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$OPENSSL_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.openssl.org/source/$OPENSSL_TAR"
then
    echo "Failed to download OpenSSL"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
gzip -d < "$OPENSSL_TAR" | tar xf -
cd "$OPENSSL_DIR" || exit 1

if [[ -e ../patch/openssl.patch ]]; then
    patch -u -p0 < ../patch/openssl.patch
    echo ""
fi

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="no-comp"

if [[ "$IS_AMD64" -eq 1 && "$INT128_OPT" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="enable-ec_nistp_64_gcc_128"
fi

# Debug symbols after install
if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="-fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${OPENSSL_DIR}"
fi

if [[ "$IS_FREEBSD" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="-Wno-error"
fi

# OpenSSL fails to link its engines and self tests on OpenBSD
if [[ "$IS_OPENBSD" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="no-engine"
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="no-tests"
    SKIP_OPENSSL_TESTS=1
fi

# Fix Alpine
if [[ "$IS_ALPINE" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="no-afalgeng"
fi

# Fix the install_name
if [[ "$IS_DARWIN" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="-Wl,-headerpad_max_install_names"
fi

# The "${CC##*/ }" strips everything proceeding
# the name of the compiler. '/bin/gcc' becomes 'gcc'.
# Otherwise, OpenSSL cannot configure itself.

    CC="${CC##*/}" \
    CXX="${CXX##*/}" \
    KERNEL_BITS="$INSTX_BITNESS" \
    CPPFLAGS="${INSTX_CPPFLAGS} -DPEDANTIC" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
./config \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --openssldir="${INSTX_PREFIX}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -eq 1 ]]; then
    echo "Failed to configure OpenSSL"
    exit 1
fi

# Fix Alpine
if [[ "$IS_ALPINE" -eq 1 ]]; then
    # This undefine's the macro after it has been set.
    echo '#undef OPENSSL_SECURE_MEMORY' >> e_os.h
    echo '' >> e_os.h
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# The OpenSSL makefile is fucked up. We can't seem to build
# only libcrypto, libssl and openssl app. The configuration
# system does not honor our options. Instead, we have to
# build everything, and work around the build failures of
# unneeded shit on some platforms.

# MAKE_FLAGS=("-j" "${INSTX_JOBS}" build_libs build_apps)
MAKE_FLAGS=("-j" "${INSTX_JOBS}" all)
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Self tests are still unreliable, https://github.com/openssl/openssl/issues/4963
if [[ "$SKIP_OPENSSL_TESTS" -eq 0 ]];
then
    MAKE_FLAGS=("-j" "${INSTX_JOBS}" test)
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "**********************"
        echo "Failed to test OpenSSL"
        echo "**********************"
        # exit 1
    fi
else
    echo "**********************"
    echo "OpenSSL is not tested"
    echo "**********************"
fi

if [[ "$IS_DARWIN" -eq 1 ]]
then
    echo "**********************"
    echo "Fixing install_name"
    echo "**********************"

    install_name_tool -id "${INSTX_LIBDIR}/libcrypto.1.1.dylib" \
        ./libcrypto.1.1.dylib
    install_name_tool -id "${INSTX_LIBDIR}/libssl.1.1.dylib" \
        ./libssl.1.1.dylib

    install_name_tool -change "${INSTX_PREFIX}//libcrypto.1.1.dylib" \
        "${INSTX_LIBDIR}/libcrypto.1.1.dylib" ./libcrypto.1.1.dylib
    install_name_tool -change "${INSTX_PREFIX}//libssl.1.1.dylib" \
        "${INSTX_LIBDIR}/libssl.1.1.dylib" ./libcrypto.1.1.dylib

    install_name_tool -change "${INSTX_PREFIX}//libcrypto.1.1.dylib" \
        "${INSTX_LIBDIR}/libcrypto.1.1.dylib" ./libssl.1.1.dylib
    install_name_tool -change "${INSTX_PREFIX}//libssl.1.1.dylib" \
        "${INSTX_LIBDIR}/libssl.1.1.dylib" ./libssl.1.1.dylib

    install_name_tool -change "${INSTX_PREFIX}//libcrypto.1.1.dylib" \
        "${INSTX_LIBDIR}/libcrypto.1.1.dylib" ./apps/openssl
    install_name_tool -change "${INSTX_PREFIX}//libssl.1.1.dylib" \
        "${INSTX_LIBDIR}/libssl.1.1.dylib" ./apps/openssl
fi

echo "**********************"
echo "Installing package"
echo "**********************"

# Install the software only
MAKE_FLAGS=(install_sw)
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
        printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${OPENSSL_DIR}"
    fi
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${OPENSSL_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
