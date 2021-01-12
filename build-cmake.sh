#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds CMake and its dependencies from sources.

CMAKE_VER="3.14.3"
CMAKE_TAR=cmake-"$CMAKE_VER".tar.gz
CMAKE_DIR=cmake-"$CMAKE_VER"

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

if ! ./setup-cacerts.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Cmake ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CMAKE_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/$CMAKE_TAR"
then
    echo "Failed to download CMake"
    exit 1
fi

rm -rf "$CMAKE_DIR" &>/dev/null
gzip -d < "$CMAKE_TAR" | tar xf -

cd "$CMAKE_DIR"

echo "**********************"
echo "Bootstrapping package"
echo "**********************"

if [[ "$IS_AIX" -ne 0 ]]; then
  AIX_TOC=-Wl,-bbigtoc
else
  AIX_TOC=
fi

# Bootstrap does not honor these, but we need to try...
export PKG_CONFIG_PATH="${INSTX_PKGCONFIG}"
export CPPFLAGS="${INSTX_CPPFLAGS}"
export ASFLAGS="${INSTX_ASFLAGS}"
export CFLAGS="${INSTX_CFLAGS}"
export CXXFLAGS="${INSTX_CXXFLAGS}"
export LDFLAGS="${INSTX_LDFLAGS} ${AIX_TOC}"
export LIBS="${INSTX_LDLIBS}"

# This is the CMake build command per https://cmake.org/install/
if ! ./bootstrap --no-system-libs --prefix="${INSTX_PREFIX}"
then
    echo "Failed to bootstrap CMake"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build CMake"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test CMake"
   exit 1
fi

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

cd "$CURR_DIR" || exit 1

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$CMAKE_TAR" "$CMAKE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
