#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds P11-Kit from sources.

P11KIT_VER=0.25.0
P11KIT_XZ=p11-kit-"$P11KIT_VER".tar.xz
P11KIT_TAR=p11-kit-"$P11KIT_VER".tar
P11KIT_DIR=p11-kit-"$P11KIT_VER"
PKG_NAME=p11-kit

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

if ! ./build-libtasn1.sh
then
    echo "Failed to build libtasn1"
    exit 1
fi

###############################################################################

if ! ./build-libffi.sh
then
    echo "Failed to build libffi"
    exit 1
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

echo ""
echo "========================================"
echo "================ P11-kit ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "${WGET}" -q -O "$P11KIT_XZ" --ca-certificate="${GITHUB_CA_ZOO}" \
     "https://github.com/p11-glue/p11-kit/releases/download/$P11KIT_VER/$P11KIT_XZ"
then
    echo "Failed to download p11-kit"
    exit 1
fi

rm -rf "$P11KIT_TAR" "$P11KIT_DIR" &>/dev/null
unxz "$P11KIT_XZ" && tar -xf "$P11KIT_TAR"
cd "$P11KIT_DIR"

if [[ -e ../patch/p11kit.patch ]]; then
    patch -u -p0 < ../patch/p11kit.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--with-libiconv-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--with-libintl-prefix=${INSTX_PREFIX}")
CONFIG_OPTS+=("--without-systemd")
CONFIG_OPTS+=("--without-bash-completion")

# Use the path if available
if [[ -n "$INSTX_CACERT_PATH" ]]; then
    CONFIG_OPTS+=("--with-trust-paths=$INSTX_CACERT_PATH")
else
    CONFIG_OPTS+=("--without-trust-paths")
fi

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    INSTX_CPPFLAGS+=("-D_XOPEN_SOURCE=500")
    INSTX_LDFLAGS=("-lsocket -lnsl ${INSTX_LDFLAGS}")
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
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure p11-kit"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

# On Solaris the script puts /usr/gnu/bin on-path, so we get a useful grep
if [[ "$IS_SOLARIS" -ne 0 ]]; then
    for file in $(grep -IR '#define _XOPEN_SOURCE' "$PWD" | cut -f 1 -d ':' | sort | uniq)
    do
        sed -e '/#define _XOPEN_SOURCE/d' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
    done
fi

# https://github.com/p11-glue/p11-kit/issues/289
file=p11-kit/test-rpc.c
sed 's/0xFFFFFFFFFFFFFFFF/0xFFFFFFFFFFFFFFFFull/g' "$file" > "$file.fixed"
mv "$file.fixed" "$file"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build p11-kit"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Testing package"
echo "**********************"

# https://bugs.freedesktop.org/show_bug.cgi?id=103402
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test p11-kit"
    # exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$P11KIT_XZ" "$P11KIT_TAR" "$P11KIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
