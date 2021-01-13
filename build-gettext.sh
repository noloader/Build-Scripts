#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GetText and friends from sources.

# GetText is really unique among packages. It has circular dependencies on
# iConv, libunistring and libxml2. build-iconv-gettext.sh handles the
# iConv and GetText dependency. This script, build-gettext-final.sh,
# handles the libunistring and libxml2 dependencies.
#
# The way to run these scripts is, run build-iconv-gettext.sh first.
# That bootstraps iConv and GetText. Second, run build-gettext-final.sh.
# That gets the missing pieces, like libunistring and libxml support.
#
# For the iConv and GetText recipe, see
# https://www.gnu.org/software/libiconv/.
#
# Here are the interesting dependencies:
#
#   libgettextlib.so: libiconv.so
#   libgettextpo.so:  libiconv.so, libiunistring.so
#   libgettextsrc.so: libz.so, libiconv.so, libiunistring.so, libxml2.so,
#                     libtinfow.so, libgettextlib.so, libtextstyle.so
#   libiconv.so:      libgettextlib.so
#   libiunistring.so: libiconv.so

GETTEXT_VER=0.21
GETTEXT_TAR="gettext-${GETTEXT_VER}.tar.gz"
GETTEXT_DIR="gettext-${GETTEXT_VER}"
PKG_NAME=gettext

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

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
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
echo "=============== GetText ================"
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

echo ""
echo "GetText ${GETTEXT_VER}..."

if ! "$WGET" -q -O "$GETTEXT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/gettext/$GETTEXT_TAR"
then
    echo "Failed to download GetText"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$GETTEXT_DIR" &>/dev/null
gzip -d < "$GETTEXT_TAR" | tar xf -
cd "$GETTEXT_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/gettext.patch ]]; then
    patch -u -p0 < ../patch/gettext.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

# Some non-GNU systems have Gzip, but it is anemic.
# GZIP_ENV = --best causes an autopoint-3 test failure.
IFS= find "$PWD" -name 'Makefile.in' -print | while read -r file
do
    sed -e 's/GZIP_ENV = --best/GZIP_ENV = -7/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if [ -e "${INSTX_PREFIX}/bin/sed" ]; then
    export SED="${INSTX_PREFIX}/bin/sed"
fi

echo "***************************"
echo "Configuring package"
echo "***************************"

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
    --enable-static \
    --enable-shared \
    --with-pic \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libncurses-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]
then
    echo "***************************"
    echo "Failed to configure GetText"
    echo "***************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to build GetText"
    echo "***************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

if [[ "$INSTX_DISABLE_GETTEXT_CHECK" -ne 1 ]];
then

    echo "***************************"
    echo "Testing package"
    echo "***************************"

    MAKE_FLAGS=("check")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "***************************"
        echo "Failed to test GetText"
        echo "***************************"

        bash ../collect-logs.sh "${PKG_NAME}"

        # Solaris and some friends fail lang-gawk
        # Darwin fails copy-acl-2.sh
        # https://lists.gnu.org/archive/html/bug-gawk/2018-01/msg00026.html
        # exit 1
    fi

    # Fix runpaths again
    bash ../fix-runpath.sh
fi

echo "***************************"
echo "Installing package"
echo "***************************"

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
    ARTIFACTS=("$GETTEXT_TAR" "$GETTEXT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
