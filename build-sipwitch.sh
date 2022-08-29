#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SIP Witch from sources.

SIPW_TAR=sipwitch-1.9.15.tar.gz
SIPW_DIR=sipwitch-1.9.15
PKG_NAME=sipwitch

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

if ! ./build-libexosip2-rc.sh
then
    echo "Failed to build libosip2"
    exit 1
fi

###############################################################################

if ! ./build-ucommon.sh
then
    echo "Failed to build ucommon"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "============== SIP Witch ==============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "${WGET}" -q -O "$SIPW_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://ftp.gnu.org/gnu/sipwitch/$SIPW_TAR"
then
    echo "Failed to download SIP Witch"
    exit 1
fi

rm -rf "$SIPW_DIR" &>/dev/null
gzip -d < "$SIPW_TAR" | tar xf -
cd "$SIPW_DIR" || exit 1

#cp common/voip.cpp common/voip.cpp.orig
#cp utils/sipquery.cpp utils/sipquery.cpp.orig
#cp server/stack.cpp server/stack.cpp.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/sipwitch-rc.patch ]]; then
    patch -u -p0 < ../patch/sipwitch-rc.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

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
    --sysconfdir="${INSTX_PREFIX}/etc" \
    --localstatedir="${INSTX_PREFIX}/var" \
    --with-pkg-config \
    --with-libeXosip2=libeXosip2 \
    --enable-openssl

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SIP Witch"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

# Fix makefiles again
IFS= find "./" -iname 'Makefile' -print | while read -r file
do
    echo "$file" | sed 's/^\.\///g'

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"
    sed -e "s/ libosip2/ -leXosip2/g" \
        -e "s/ libeXosip2/ -leXosip2/g" \
        "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-k" "-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build SIP Witch"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to test SIP Witch"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "***************************"
echo "Installing package"
echo "***************************"

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
    ARTIFACTS=("$SIPW_TAR" "$SIPW_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
