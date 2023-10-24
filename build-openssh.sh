#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SSH and its dependencies from sources.
# Also see https://superuser.com/q/961349/173513.

OPENSSH_VER=9.5p1
OPENSSH_TAR="openssh-${OPENSSH_VER}.tar.gz"
OPENSSH_DIR="openssh-${OPENSSH_VER}"
PKG_NAME=openssh

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

# LDNS and dependencies will probably fail
# to build, like on OS X 10.5.

if [[ "$IS_DARWIN" -eq 0 ]]; then
    enable_ldns=1
elif [[ "${OSX_10p8_OR_ABOVE}" -eq 1 ]]; then
    enable_ldns=1
else
    enable_ldns=0
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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if [[ "${enable_ldns}" -eq 1 ]]
then
    if ! ./build-ldns.sh
    then
        echo "Failed to build LDNS"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================ OpenSSH ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "${WGET}" -q -O "$OPENSSH_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "http://ftp.usa.openbsd.org/pub/OpenBSD/OpenSSH/portable/$OPENSSH_TAR"
then
    echo "Failed to download SSH"
    echo "Maybe Wget is too old. Perhaps run setup-wget.sh?"
    exit 1
fi

rm -rf "$OPENSSH_DIR" &>/dev/null
gzip -d < "$OPENSSH_TAR" | tar xf -
cd "$OPENSSH_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cppflags=${INSTX_CPPFLAGS}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-asflags=${INSTX_ASFLAGS}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cflags=${INSTX_CFLAGS}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldflags=${INSTX_CFLAGS} ${INSTX_LDFLAGS}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-libs=-lz ${INSTX_LDLIBS}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-zlib=${INSTX_PREFIX}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ssl-dir=${INSTX_PREFIX}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-pie"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--disable-strip"

if [[ "${enable_ldns}" -eq 1 ]]
then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldns=${INSTX_PREFIX}"
fi

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    openssh_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${OPENSSH_DIR}"
    openssh_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${OPENSSH_DIR}"
else
    openssh_cflags="${INSTX_CFLAGS}"
    openssh_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${openssh_cflags}" \
    CXXFLAGS="${openssh_cxxflags}" \
    LDFLAGS="${INSTX_CFLAGS} ${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SSH"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build SSH"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test OpenSSH"
echo 'https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw'
echo

# No way to test OpenSSH after build...
# https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw
#MAKE_FLAGS=("check" "-k" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

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
    ARTIFACTS=("$OPENSSH_TAR" "$OPENSSH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
