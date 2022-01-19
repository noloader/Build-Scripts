#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script downloads patchelf prebuilt binary for Linux
# and installs it in PREFIX/bin. The prebuilt binary allows
# us to cover more platforms, like Ubuntu 4 and Fedora 1.
# The old platforms lack a C++11 compiler.

PATCHELF_VER=0.14.3
PATCHELF_TAR=${PATCHELF_VER}.tar.gz
PATCHELF_DIR=patchelf-${PATCHELF_VER}
PKG_NAME=patchelf

case $(uname -m 2>/dev/null) in
    i686) PATCHELF_ARCH=i686 ;;
    x86_64|amd64) PATCHELF_ARCH=x86_64 ;;
    aarch64|arm64) PATCHELF_ARCH=aarch64 ;;
    armv7l) PATCHELF_ARCH=armv7l ;;
    ppc64le) PATCHELF_ARCH=ppc64le ;;
    s390x) PATCHELF_ARCH=s390x ;;
    *) PATCHELF_ARCH=unknown ;;
esac

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

###############################################################################

# Verify system uses ELF
#magic=$(cut -b 2-4 /bin/ls | head -n 1)
#if [[ "$magic" != "ELF" ]]; then
#    exit 0
#fi

# Patchelf only builds on Linux and HURD. Solaris is trouble.
if [[ "$IS_LINUX" -eq 0 && "$IS_HURD" -eq 0 ]]; then
    exit 0
fi

# patchelf is a program and it is supposed to be rebuilt
# on demand. However, we install a prebuilt binary. No
# need to puke a message for each recipe.
if [[ -e "${INSTX_PKG_CACHE}/${PKG_NAME}" ]]; then
    #echo ""
    #echo "${PKG_NAME} is already installed."
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

if ! ./setup-directories.sh
then
    echo "Failed to setup directories"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== Patchelf ==============="
echo "========================================"

echo ""
echo "****************************"
echo "Downloading package"
echo "****************************"

echo ""
echo "Patchelf ${PATCHELF_VER}..."

rm -rf "$PATCHELF_DIR" && mkdir -p "$PATCHELF_DIR" && cd "$PATCHELF_DIR" || exit 1

if ! "${WGET}" -q -O "${PATCHELF_TAR}" --ca-certificate="$GITHUB_CA_ZOO" \
     "https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VER}/patchelf-${PATCHELF_VER}-${PATCHELF_ARCH}.tar.gz"
then
    echo "Failed to download patchelf"
    exit 1
fi

# The binary is prebuilt so we only need to unpack it
gzip -d < "$PATCHELF_TAR" | tar xf -

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo mkdir -p "${INSTX_PREFIX}/bin"
    printf "%s\n" "$SUDO_PASSWORD" | sudo cp -p bin/patchelf "${INSTX_PREFIX}/bin"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../fix-permissions.sh "${INSTX_PREFIX}"
else
    mkdir -p "${INSTX_PREFIX}/bin"
    cp -p bin/patchelf "${INSTX_PREFIX}/bin"
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
    ARTIFACTS=("${PATCHELF_TAR}" "${PATCHELF_DIR}")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
