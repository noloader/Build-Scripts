#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Autotools from sources. A separate
# script is available for Libtool for brave souls.

# Trying to update Autotools may be more trouble than it is
# worth. If the upgrade goes bad, then you can uninstall
# it with the script clean-autotools.sh

M4_VER=1.4.18
M4_TAR="m4-${M4_VER}.tar.gz"
M4_DIR="m4-${M4_VER}"

AUTOCONF_VER=2.70
AUTOCONF_TAR="autoconf-${AUTOCONF_VER}.tar.gz"
AUTOCONF_DIR="autoconf-${AUTOCONF_VER}"

AUTOMAKE_VER=1.16.3
AUTOMAKE_TAR="automake-${AUTOMAKE_VER}.tar.gz"
AUTOMAKE_DIR="automake-${AUTOMAKE_VER}"

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

echo ""
echo "========================================"
echo "================== M4 =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "M4 ${M4_VER}..."

if ! "$WGET" -q -O "$M4_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/m4/$M4_TAR"
then
    echo "Failed to download M4"
    exit 1
fi

rm -rf "$M4_DIR" &>/dev/null
gzip -d < "$M4_TAR" | tar xf -
cd "$M4_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

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
    --libdir="${INSTX_LIBDIR}" \
    --enable-c++

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "**********************"
    echo "Failed to configure M4"
    echo "**********************"

    bash ../collect-logs.sh "m4"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "MAKEINFO=true" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "**********************"
    echo "Failed to build M4"
    echo "**********************"

    bash ../collect-logs.sh "m4"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "${CURR_DIR}" || exit 1

# Update program cache
hash -r &>/dev/null

###############################################################################

echo ""
echo "========================================"
echo "=============== Autoconf ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Autoconf ${AUTOCONF_VER}..."

if ! "$WGET" -q -O "$AUTOCONF_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/autoconf/$AUTOCONF_TAR"
then
    echo "Failed to download Autoconf"
    exit 1
fi

rm -rf "$AUTOCONF_DIR" &>/dev/null
gzip -d < "$AUTOCONF_TAR" | tar xf -
cd "$AUTOCONF_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
    M4="${INSTX_PREFIX}/bin/m4" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "****************************"
    echo "Failed to configure Autoconf"
    echo "****************************"

    bash ../collect-logs.sh "autoconf"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build Autoconf"
    echo "****************************"

    bash ../collect-logs.sh "autoconf"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "${CURR_DIR}" || exit 1

# Update program cache
hash -r &>/dev/null

###############################################################################

echo ""
echo "========================================"
echo "=============== Automake ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

echo ""
echo "Automake ${AUTOMAKE_VER}..."

if ! "$WGET" -q -O "$AUTOMAKE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/automake/$AUTOMAKE_TAR"
then
    echo "Failed to download Automake"
    exit 1
fi

rm -rf "$AUTOMAKE_DIR" &>/dev/null
gzip -d < "$AUTOMAKE_TAR" | tar xf -
cd "$AUTOMAKE_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "**********************"
echo "Configuring package"
echo "**********************"

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

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "****************************"
    echo "Failed to configure Automake"
    echo "****************************"

    bash ../collect-logs.sh "automake"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo ""
echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}" "MAKEINFO=true" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "****************************"
    echo "Failed to build Automake"
    echo "****************************"

    bash ../collect-logs.sh "automake"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo ""
echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash ../fix-permissions.sh "${INSTX_PREFIX}"
fi

cd "${CURR_DIR}" || exit 1

# Update program cache
hash -r &>/dev/null

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
    ARTIFACTS=("$M4_TAR" "$M4_DIR" "$AUTOCONF_TAR"
        "$AUTOCONF_DIR" "$AUTOMAKE_TAR" "$AUTOMAKE_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
