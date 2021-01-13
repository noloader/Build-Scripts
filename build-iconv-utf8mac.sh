#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv from sources.

# iConv and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-iconv.sh directly

# iConv has additional hardships. The maintainers don't approve of
# Apple's UTF-8-Mac so they don't support it. Lack of UTF-8-Mac support
# on OS X causes other programs to fail, like Git. Also see
# https://marc.info/?l=git&m=158857581228100. That leaves two choices.
# First, use a GitHub like https://github.com/fumiyas/libiconv-utf8mac.
# Second, use Apple's sources at http://opensource.apple.com/tarballs/.
# Apple's libiconv-59 is really libiconv 1.11 in disguise. So we use
# the first method, clone libiconv-utf8mac, build a release tarball,
# and then use it in place of the GNU package.

ICONV_VER=1.16
ICONV_TAR="libiconv-utf8mac-${ICONV_VER}.tar.gz"
ICONV_DIR="libiconv-utf8mac-${ICONV_VER}"
PKG_NAME=iconv

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

echo ""
echo "========================================"
echo "============ iConv utf8mac ============="
echo "========================================"

echo ""
echo "*************************"
echo "Downloading package"
echo "*************************"

echo ""
echo "iConv ${ICONV_VER}..."

if ! "$WGET" -q -O "$ICONV_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/noloader/libiconv-utf8mac/releases/download/v1_16/$ICONV_TAR"
then
    echo "Failed to download iConv"
    exit 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
gzip -d < "$ICONV_TAR" | tar xf -
cd "$ICONV_DIR" || exit 1

# libiconv-utf8mac already has patch applied
# libiconv still needs the patch
#if [[ -e ../patch/iconv.patch ]]; then
#    patch -u -p0 < ../patch/iconv.patch
#    echo ""
#fi

# https://github.com/fumiyas/libiconv-utf8mac/commit/561d8c83506f
if ! "$WGET" -q -O lib/utf8mac.h --ca-certificate="$GITHUB_ROOT" \
    https://raw.githubusercontent.com/fumiyas/libiconv-utf8mac/utf-8-mac-51.200.6.libiconv-${ICONV_VER}/lib/utf8mac.h
then
    echo "Failed to patch iConv"
    exit 1
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
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --enable-shared \
    --with-libintl-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]
then
    echo "*************************"
    echo "Failed to configure iConv"
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
    echo "Failed to build iConv"
    echo "*************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

# build-iconv-gettext has a circular dependency.
# The first build of iConv does not need 'make check'.
if [[ "${INSTX_DISABLE_ICONV_TEST:-0}" -ne 1 ]]
then
    echo "*************************"
    echo "Testing package"
    echo "*************************"

    MAKE_FLAGS=("check" "-k" "V=1")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "*************************"
        echo "Failed to test iConv"
        echo "*************************"

        bash ../collect-logs.sh "${PKG_NAME}"
        exit 1
    fi
fi

# Fix runpaths again
bash ../fix-runpath.sh

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

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$ICONV_TAR" "$ICONV_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
