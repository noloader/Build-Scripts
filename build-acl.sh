#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libacl from sources.

ACL_VER=2.2.53
ACL_TAR=acl-${ACL_VER}.tar.gz
ACL_DIR=acl-${ACL_VER}
PKG_NAME=acl

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

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

if ! ./build-attr.sh
then
    echo "Failed to build libattr"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ libacl ================"
echo "========================================"

echo ""
echo "**************************"
echo "Downloading package"
echo "**************************"

echo ""
echo "libacl ${ACL_VER}..."

if ! "$WGET" -q -O "$ACL_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://download.savannah.nongnu.org/releases/acl/$ACL_TAR"
then
    echo "Failed to download libacl"
    exit 1
fi

rm -rf "$ACL_DIR" &>/dev/null
gzip -d < "$ACL_TAR" | tar xf -
cd "$ACL_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/acl.patch ]]; then
    echo ""
    echo "**************************"
    echo "Patching package"
    echo "**************************"

    patch -u -p0 < ../patch/acl.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**************************"
echo "Configuring package"
echo "**************************"

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
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]
then
    echo ""
    echo "**************************"
    echo "Failed to configure libacl"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**************************"
echo "Building package"
echo "**************************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to build libacl"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "**************************"
echo "Testing package"
echo "**************************"

# Musl workaround. Musl does not load warez with a
# non-working rpath or runpath. Of course the runpath
# is not correct before install! Derp...
mkdir -p "$(echo ${INSTX_OPATH} | sed 's/\$ORIGIN\///g')"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to test libacl"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

echo ""
echo "**************************"
echo "Installing package"
echo "**************************"

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
    ARTIFACTS=("$ACL_TAR" "$ACL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
