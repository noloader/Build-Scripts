#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds pkg-config from sources.

# On OS X, we may need to install pkg-config before running setup-wget.sh.
# OS X has cURL by default, so use it instead of Wget when Wget is not available.

PKGCONFIG_VER=0.29.2
PKGCONFIG_TAR=pkg-config-${PKGCONFIG_VER}.tar.gz
PKGCONFIG_DIR=pkg-config-${PKGCONFIG_VER}
PKG_NAME=pkg-config

###############################################################################

# pkg-config is special
export INSTX_DISABLE_PKGCONFIG_CHECK=1
export INSTX_DISABLE_WGET_CHECK=1

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

unset INSTX_DISABLE_PKGCONFIG_CHECK
unset INSTX_DISABLE_WGET_CHECK

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

echo ""
echo "========================================"
echo "============== pkg-config =============="
echo "========================================"

echo ""
echo "******************************"
echo "Downloading package"
echo "******************************"

if [[ -n $(command -v "${WGET}" 2>/dev/null) ]]
then
    if ! "${WGET}" -q -O "$PKGCONFIG_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
elif [[ -n $(command -v curl 2>/dev/null) ]]
then
    if ! curl -s -o "$PKGCONFIG_TAR" --cacert "${LETS_ENCRYPT_ROOT}" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
else
    echo "Wget and cURL are not available. We give up. Please install"
    echo "pkg-config from https://pkg-config.freedesktop.org/releases."
    exit 1
fi

rm -rf "$PKGCONFIG_DIR" &>/dev/null
gzip -d < "$PKGCONFIG_TAR" | tar xf -
cd "$PKGCONFIG_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "******************************"
echo "Configuring package"
echo "******************************"

CONFIG_OPTS=()
if [[ "$IS_DARWIN" -ne 0 ]]; then
    CONFIG_OPTS+=("--with-internal-glib")
#elif [[ "$IS_SOLARIS" -ne 0 ]]; then
#    CONFIG_OPTS+=("--with-internal-glib")
elif [[ "$IS_DRAGONFLY" -ne 0 ]]; then
    CONFIG_OPTS+=("--with-internal-glib")
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
    echo ""
    echo "******************************"
    echo "Failed to configure pkg-config"
    echo "******************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "******************************"
echo "Building package"
echo "******************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "MAKEINFO=true" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "******************************"
    echo "Failed to build pkg-config"
    echo "******************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "******************************"
echo "Installing package"
echo "******************************"

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
    ARTIFACTS=("$PKGCONFIG_TAR" "$PKGCONFIG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
