#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GMP from sources.

GMP_VER=6.2.1
GMP_TAR="gmp-${GMP_VER}.tar.bz2"
GMP_DIR="gmp-${GMP_VER}"
PKG_NAME=gmp

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

echo ""
echo "========================================"
echo "================= GMP =================="
echo "========================================"

echo ""
echo "***********************"
echo "Downloading package"
echo "***********************"

echo ""
echo "GMP ${GMP_VER}..."

if ! "$WGET" -q -O "$GMP_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/gmp/$GMP_TAR"
then
    echo ""
    echo "***********************"
    echo "Failed to download GMP"
    echo "***********************"
    exit 1
fi

rm -rf "$GMP_DIR" &>/dev/null
bzip2 -d < "$GMP_TAR" | tar xf -
cd "$GMP_DIR" || exit 1

if [[ -e ../patch/gmp.patch ]]; then
    echo ""
    echo "*************************"
    echo "Patching package"
    echo "*************************"

    patch -u -p0 < ../patch/gmp.patch
fi

# Fix decades old compile and link errors on early Darwin.
# https://gmplib.org/list-archives/gmp-bugs/2009-May/001423.html
if [[ "$OSX_10p5_OR_BELOW" -ne 0 ]]; then
    if [[ -e ../patch/gmp-darwin.patch ]]; then
        echo ""
        echo "*************************"
        echo "Patching package (Darwin)"
        echo "*************************"

        patch -u -p0 < ../patch/gmp-darwin.patch
    fi
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

# Fix FreeBSD configure test
if true; then
    file=configure
    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"
    sed 's/__builtin_clzl//g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod a+x "$file"; chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm -f "$file.timestamp" "$file.fixed"
fi

echo ""
echo "***********************"
echo "Configuring package"
echo "***********************"

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    gmp_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GMP_DIR}"
    gmp_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GMP_DIR}"
else
    gmp_cflags="${INSTX_CFLAGS}"
    gmp_cxxflags="${INSTX_CXXFLAGS}"
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-assert=no")
CONFIG_OPTS+=("ABI=$INSTX_BITNESS")

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${gmp_cflags}" \
    CXXFLAGS="${gmp_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***********************"
    echo "Failed to configure GMP"
    echo "***********************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "***********************"
echo "Building package"
echo "***********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***********************"
    echo "Failed to build GMP"
    echo "***********************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo ""
echo "***********************"
echo "Testing package"
echo "***********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***********************"
    echo "Failed to test GMP"
    echo "***********************"

    bash ../collect-logs.sh "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo ""
echo "***********************"
echo "Installing package"
echo "***********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${GMP_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${GMP_DIR}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GMP_TAR" "$GMP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
