
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuPG and its dependencies from sources.

GNUPG_VER=2.4.3
GNUPG_TAR="gnupg-${GNUPG_VER}.tar.bz2"
GNUPG_DIR="gnupg-${GNUPG_VER}"
PKG_NAME=gnupg

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
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

if ! ./build-libtasn1.sh
then
    echo "Failed to build libtasn1"
    exit 1
fi

###############################################################################

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgpg-error"
    exit 1
fi

###############################################################################

if ! ./build-libksba.sh
then
    echo "Failed to build Libksba"
    exit 1
fi

###############################################################################

if ! ./build-libassuan.sh
then
    echo "Failed to build Libassuan"
    exit 1
fi

###############################################################################

if ! ./build-libgcrypt.sh
then
    echo "Failed to build Libgcrypt"
    exit 1
fi

###############################################################################

if ! ./build-ntbTLS.sh
then
    echo "Failed to build ntbTLS"
    exit 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ GnuPG ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "GnuPG ${GNUPG_VER}..."

if ! "${WGET}" -q -O "$GNUPG_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TAR"
then
    echo ""
    echo "***************************"
    echo "Failed to download GnuPG"
    echo "***************************"
    exit 1
fi

rm -rf "$GNUPG_DIR" &>/dev/null
tar xjf "$GNUPG_TAR"
cd "$GNUPG_DIR"

if [[ -e ../patch/gnupg.patch ]]; then
    echo ""
    echo "**********************"
    echo "Patching package"
    echo "**********************"

    patch -u -p0 < ../patch/gnupg.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    gnupg_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GNUPG_DIR}"
    gnupg_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GNUPG_DIR}"
else
    gnupg_cflags="${INSTX_CFLAGS}"
    gnupg_cxxflags="${INSTX_CXXFLAGS}"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${gnupg_cflags}" \
    CXXFLAGS="${gnupg_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --disable-scdaemon \
    --disable-dirmngr \
    --disable-wks-tools \
    --disable-doc \
    --with-zlib="${INSTX_PREFIX}" \
    --with-bzip2="${INSTX_PREFIX}" \
    --with-libgpg-error-prefix="${INSTX_PREFIX}" \
    --with-libgcrypt-prefix="${INSTX_PREFIX}" \
    --with-libassuan-prefix="${INSTX_PREFIX}" \
    --with-ksba-prefix="${INSTX_PREFIX}" \
    --with-npth-prefix="${INSTX_PREFIX}" \
    --with-ntbtls-prefix="${INSTX_PREFIX}" \
    --with-libiconv-prefix="${INSTX_PREFIX}" \
    --with-libintl-prefix="${INSTX_PREFIX}"

if [[ "$?" -ne 0 ]]
then
    echo ""
    echo "***************************"
    echo "Failed to configure GnuPG"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to build GnuPG"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to test GnuPG"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GNUPG_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GNUPG_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GNUPG_TAR" "$GNUPG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
