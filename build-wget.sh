#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and its dependencies from sources.

WGET_VER=1.21.1
WGET_TAR=wget-${WGET_VER}.tar.gz
WGET_DIR=wget-${WGET_VER}

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

# c-ares needs a C++11 compiler. c-ares fails its self tests on Solaris.
if [[ "$INSTX_CXX11" -eq 0 || "$IS_SOLARIS" -ne 0 ]]
then
    ENABLE_CARES=0
else
    ENABLE_CARES=1
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

if [[ "$ENABLE_CARES" -eq 1 ]]
then
    if ! ./build-cares.sh
    then
        echo "Failed to build c-ares"
        exit 1
    fi
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

# Optional. For Solaris see https://community.oracle.com/thread/1915569.
SKIP_WGET_TESTS=0
if [[ -z "$(command -v perl 2>/dev/null)" ]]; then
    SKIP_WGET_TESTS=1
else
    if ! perl -MHTTP::Daemon -e1 2>/dev/null
    then
         echo ""
         echo "Wget requires Perl's HTTP::Daemon. Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Daemon."
         SKIP_WGET_TESTS=1
    fi

    if ! perl -MHTTP::Request -e1 2>/dev/null
    then
         echo ""
         echo "Wget requires Perl's HTTP::Request. Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Request or HTTP-Message."
         SKIP_WGET_TESTS=1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Wget ================="
echo "========================================"

echo ""
echo "************************"
echo "Downloading package"
echo "************************"

if ! "$WGET" -q -O "$WGET_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/wget/$WGET_TAR"
then
    echo "Failed to download Wget"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$WGET_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/wget.patch ]]; then
    patch -u -p0 < ../patch/wget.patch
    echo ""
fi

# https://lists.gnu.org/archive/html/bug-gnulib/2019-07/msg00058.html
IFS= find "$PWD" -name '*.h' -print | while read -r file
do
    touch -a -m -r "$file" "$file.timestamp"
    chmod u+w "$file" && cp -p "$file" "$file.fixed"

    sed -e 's/__GNUC_PREREQ (3, 3)/__GNUC_PREREQ (4, 0)/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"

    chmod a+r "$file" && chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

# https://lists.gnu.org/archive/html/bug-wget/2019-05/msg00064.html
IFS= find "$PWD" -name '*.px' -print | while read -r file
do
    touch -a -m -r "$file" "$file.timestamp"
    chmod u+w "$file" && cp -p "$file" "$file.fixed"

    sed -e 's/env -S perl -I ./env perl/g' "$file" > "$file.fixed"

    chmod a+x "$file" && chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "************************"
echo "Configuring package"
echo "************************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--with-ssl=openssl")
CONFIG_OPTS+=("--with-openssl=yes")

if [[ "$ENABLE_CARES" -eq 1 ]]; then
    CONFIG_OPTS+=("--with-cares")
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --sysconfdir="${INSTX_PREFIX}/etc" \
    --with-libintl-prefix="${INSTX_PREFIX}" \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libunistring-prefix="${INSTX_PREFIX}" \
    --with-libssl-prefix="${INSTX_PREFIX}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "************************"
    echo "Failed to configure Wget"
    echo "************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "************************"
echo "Building package"
echo "************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "************************"
    echo "Failed to build Wget"
    echo "************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "************************"
echo "Testing package"
echo "************************"

if [[ "$SKIP_WGET_TESTS" -eq 0 ]]
then
    # Perl IPv6 may be broken and cause Wget self tests to fail.
    # Ignore failures about Socket::inet_itoa and incorrect sizes.
    # https://rt.cpan.org/Public/Bug/Display.html?id=91699
    # Perl does not include PWD so it compiles and executes
    # tests like Test-https-pfs.px, but fails to find
    # WgetFeature.pm which is located in the same directory.
    # I fail to see the difference in risk. How is
    # Test-https-pfs.px safe, but WgetFeature.pm dangerous?
    MAKE_FLAGS=("check" "-k" "V=1")
    if ! PERL_USE_UNSAFE_INC=1 "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "************************"
        echo "Failed to test Wget"
        echo "Installing anyway..."
        echo "************************"

        bash ../collect-logs.sh "${PKG_NAME}"
        # exit 1
    fi
else
    echo "************************"
    echo "Wget not tested."
    echo "************************"
fi

echo "************************"
echo "Installing package"
echo "************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

# Wget does not have any CA's configured at the moment. HTTPS downloads
# will fail with the message "... use --no-check-certifcate ...". Fix it
# through the system's wgetrc configuration file.
cp "./doc/sample.wgetrc" "./wgetrc"
{
    echo ""
    echo "# Default CA Zoo file added by Build-Scripts"
    echo "ca_directory = $INSTX_CACERT_PATH"
    echo "ca_certificate = $INSTX_CACERT_FILE"
    echo ""
} > "./wgetrc"

# Install the rc file
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S mkdir -p "${INSTX_PREFIX}/etc"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S cp "./wgetrc" "${INSTX_PREFIX}/etc/"
else
    mkdir -p "${INSTX_PREFIX}/etc"
    cp "./wgetrc" "${INSTX_PREFIX}/etc/"
fi

# Fix permissions once
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to true to retain artifacts
if true;
then
    ARTIFACTS=("$WGET_TAR" "$WGET_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
