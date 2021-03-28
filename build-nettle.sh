#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Nettle from sources.

NETTLE_VER=3.7.2
NETTLE_TAR=nettle-${NETTLE_VER}.tar.gz
NETTLE_DIR=nettle-${NETTLE_VER}
PKG_NAME=nettle

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

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Nettle ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Nettle ${NETTLE_VER}..."

if ! "$WGET" -q -O "$NETTLE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/nettle/$NETTLE_TAR"
then
    echo "Failed to download Nettle"
    exit 1
fi

rm -rf "$NETTLE_DIR" &>/dev/null
gzip -d < "$NETTLE_TAR" | tar xf -
cd "$NETTLE_DIR" || exit 1

if [[ -e ../patch/nettle.patch ]]; then
    echo ""
    echo "***************************"
    echo "Patching package"
    echo "***************************"

    patch -u -p0 < ../patch/nettle.patch
fi

if [[ -e ../patch/nettle-darwin.patch ]]; then
    echo ""
    echo "***************************"
    echo "Patching package (Darwin)"
    echo "***************************"

    patch -u -p0 < ../patch/nettle-darwin.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

# Awful Solaris 64-bit hack. Use -G for SunC, and -shared for GCC
if [[ "$IS_SOLARIS" -ne 0 && "$IS_SUNC" -eq 0 ]]; then
    file=configure
    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"; chmod a+x "$file"
    sed 's/ -G / -shared /g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod a+x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm -f "$file.timestamp" "$file.fixed"
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--disable-documentation")

if [[ "$IS_IA32" -eq 1 ]]
then
    have_aes=$(${CC} ${CFLAGS} -maes -dM -E - </dev/null 2>&1 | grep -i -c '__AES__')
    have_sha=$(${CC} ${CFLAGS} -msha -dM -E - </dev/null 2>&1 | grep -i -c '__SHA__')

    if [[ "$have_aes" -eq 0 ]]; then
        CONFIG_OPTS+=("--disable-x86-aesni")
    fi

    if [[ "$have_sha" -eq 0 ]]; then
        CONFIG_OPTS+=("--disable-x86-sha-ni")
    fi

    if [[ "$have_aes" -eq 1 || if [[ "$have_sha" -eq 1 ]]; then ]]; then
        CONFIG_OPTS+=("--enable-fat")
    fi
fi

if [[ "$IS_ARM_NEON" -eq 1 ]]
then
    have_neon=$(${CC} ${CFLAGS} -dM -E - </dev/null 2>&1 | grep -i -c '__ARM_NEON')

    if [[ "$have_neon" -eq 1 ]]; then
        CONFIG_OPTS+=("--enable-fat")
    fi
fi

if [[ "$IS_ARMV8" -eq 1 ]]
then
    if [[ $(true) ]]; then
        CONFIG_OPTS+=("--enable-fat")
    fi
fi

if [[ "$IS_ALTIVEC" -eq 1 ]]
then
    have_altivec=$(${CC} ${CFLAGS} -maltivec -dM -E - </dev/null 2>&1 | grep -i -c '__ALTIVEC__')

    if [[ "$have_altivec" -eq 1 ]]; then
        CONFIG_OPTS+=("--enable-fat")
    fi
fi

nettle_cflags="${INSTX_CFLAGS}"
nettle_cxxflags="${INSTX_CXXFLAGS}"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    nettle_cflags="${nettle_cflags} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${NETTLE_DIR}"
    nettle_cxxflags="${nettle_cxxflags} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${NETTLE_DIR}"
fi

# ac_cv_lib_gmp___gmpn_zero_p=yes due to
# https://lists.lysator.liu.se/pipermail/nettle-bugs/2021/009469.html

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${nettle_cflags}" \
    CXXFLAGS="${nettle_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    ac_cv_lib_gmp___gmpn_zero_p=yes \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "**************************"
    echo "Failed to configure Nettle"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix LD_LIBRARY_PATH and DYLD_LIBRARY_PATH
bash ../fix-library-path.sh

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "all" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to build Nettle"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "**********************"
echo "Testing package"
echo "**********************"

# I wish the maintainer would test his shit...
find . -name 'run-tests' -exec chmod +x {} \;
find . -name '*-test' -exec chmod +x {} \;
if [[ -n "$(command -v xattr 2>/dev/null)" ]]; then
    find . -name 'run-tests' -exec xattr -d com.apple.quarantine {} 2>/dev/null \;
    find . -name '*-test' -exec xattr -d com.apple.quarantine {} 2>/dev/null \;
fi

# I wish the maintainer would test his shit...
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**************************"
    echo "Failed to test Nettle"
    echo "**************************"

    bash ../collect-logs.sh "${PKG_NAME}"
    # exit 1

    # Known problems on OS X, both old and new.
    if [[ "${IS_DARWIN}" -eq 1 ]]; then
        :
    else
        exit 1
    fi

    echo ""
    echo "**************************"
    echo "Installing anyways..."
    echo "**************************"
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
        printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${NETTLE_DIR}"
    fi
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${NETTLE_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$NETTLE_TAR" "$NETTLE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
