#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget2 and its dependencies from sources.

# Per TR, the tarballs are pre-release. We should clone Master.

WGET2_DIR=wget2
PKG_NAME=wget2

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

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip"
    exit 1
fi

###############################################################################

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
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

if [[ ! -f "${INSTX_PREFIX}/bin/flex" ]]
then
    if ! ./build-flex.sh
    then
        echo "Failed to build Flex"
        exit 1
    fi
fi

###############################################################################

if [[ ! -f "${INSTX_PREFIX}/bin/grep" ]]
then
    if ! ./build-grep.sh
    then
        echo "Failed to build Grep"
        exit 1
    fi
fi

###############################################################################

if [[ ! -f "${INSTX_PREFIX}/bin/xz" ]]
then
    if ! ./build-xz.sh
    then
        echo "Failed to build XZ"
        exit 1
    fi
fi

###############################################################################

if [[ ! -f "${INSTX_PREFIX}/bin/lzip" ]]
then
    if ! ./build-lzip.sh
    then
        echo "Failed to build Lzip"
        exit 1
    fi
fi

###############################################################################

# PSL may be skipped if Python is too old. libpsl requires Python 2.7
# Also see https://stackoverflow.com/a/40950971/608639
SKIP_WGET_PSL=1
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

    SKIP_WGET_PSL=0
fi

###############################################################################

# Optional. For Solaris see https://community.oracle.com/thread/1915569.
SKIP_WGET_TESTS=0
if [[ -z $(command -v perl 2>/dev/null) ]]; then
    SKIP_WGET_TESTS=1
else
    if ! perl -MHTTP::Daemon -e1 2>/dev/null
    then
         echo ""
         echo "Wget2 requires Perl's HTTP::Daemon. Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Daemon."
         SKIP_WGET_TESTS=1
    fi

    if ! perl -MHTTP::Request -e1 2>/dev/null
    then
         echo ""
         echo "Wget2 requires Perl's HTTP::Request. Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Request or HTTP-Message."
         SKIP_WGET_TESTS=1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Wget2 ================"
echo "========================================"

#if ! "$WGET" -q -O "$WGET_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
#     "https://ftp.gnu.org/pub/gnu/wget/$WGET_TAR"
#then
#    echo "Failed to download Wget2"
#    exit 1
#fi
#
#rm -rf "$WGET2_DIR" &>/dev/null
#gzip -d < "$WGET_TAR" | tar xf -
#cd "$WGET2_DIR" || exit 1

rm -rf "$WGET2_DIR" &>/dev/null

echo ""
echo "*************************"
echo "Cloning package"
echo "*************************"

if ! git clone https://gitlab.com/gnuwget/wget2.git;
then
    echo "Failed to clone Wget2"
    exit 1
fi

cd "$WGET2_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/wget2.patch ]]; then
    patch -u -p0 < ../patch/wget2.patch
    echo ""
fi

# Hack for distro tools
export MAKEINFO=true

echo "*************************"
echo "Bootstrapping package"
echo "*************************"

if ! ./bootstrap;
then
    echo "Failed to bootstrap Wget2"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "*************************"
echo "Configuring package"
echo "*************************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--with-openssl=yes")
CONFIG_OPTS+=("--with-ssl=openssl")
CONFIG_OPTS+=("--with-libintl-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libiconv-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libidn2=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libpcre2=${INSTX_PREFIX}")
CONFIG_OPTS+=("--without-gpgme")

# CONFIG_OPTS+=("--with-libmicrohttpd=${INSTX_PREFIX}")
CONFIG_OPTS+=("--without-libmicrohttpd")

if [[ "$SKIP_WGET_PSL" -eq 1 ]]; then
    CONFIG_OPTS+=("--without-libpsl")
fi

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    wget2_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${WGET2_DIR}"
    wget2_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${WGET2_DIR}"
else
    wget2_cflags="${INSTX_CFLAGS}"
    wget2_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${wget2_cflags}" \
    CXXFLAGS="${wget2_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --sysconfdir="${INSTX_PREFIX}/etc" \
    "${CONFIG_OPTS[@]}"


if [[ "$?" -ne 0 ]]; then
    echo "*************************"
    echo "Failed to configure Wget2"
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

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "*************************"
    echo "Failed to build Wget2"
    echo "*************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "*************************"
echo "Testing package"
echo "*************************"

if [[ "$SKIP_WGET_TESTS" -eq 0 ]]
then
    MAKE_FLAGS=("check" "-k" "V=1")
    if ! PERL_USE_UNSAFE_INC=1 "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "*************************"
        echo "Failed to test Wget2"
        echo "*************************"

        bash ../collect-logs.sh "${PKG_NAME}"
        exit 1
    fi
else
    echo "*************************"
    echo "Wget2 not tested."
    echo "*************************"
fi

echo "*************************"
echo "Installing package"
echo "*************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${WGET2_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${WGET2_DIR}"
fi

# Wget does not have any CA's configured at the moment. HTTPS downloads
# will fail with the message "... use --no-check-certifcate ...". Fix it
# through the system's wget2rc configuration file.
{
    echo ""
    echo "# Default CA Zoo file added by Build-Scripts"
    echo "ca_directory = $INSTX_CACERT_PATH"
    echo "ca_certificate = $INSTX_CACERT_FILE"
    echo ""
} > ./wget2rc

# Install the rc file
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S cp "./wget2rc" "${INSTX_PREFIX}/etc/"
else
    cp "./wget2rc" "${INSTX_PREFIX}/etc/"
fi

# Fix permissions once
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

# Collect test logs for error reporting
bash ../collect-logs.sh "${PKG_NAME}"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to true to retain artifacts
if true;
then
    ARTIFACTS=("$WGET_TAR" "$WGET2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
