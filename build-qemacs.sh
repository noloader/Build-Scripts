#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds QEmacs from CVS sources.

# http://savannah.nongnu.org/cvs/?group=qemacs
# https://www.emacswiki.org/emacs/QEmacs
# http://cvs.savannah.nongnu.org/viewvc/qemacs/qemacs/

QEMACS_DIR=qemacs
PKG_NAME=qemacs

###############################################################################

# Get the environment as needed.
if [[ "${SETUP_ENVIRON_DONE}" != "yes" ]]; then
    if ! source ./setup-environ.sh
    then
        echo "Failed to set environment"
        exit 1
    fi
fi

if [[ -z "$(command -v cvs)" ]]; then
    echo "QEmacs requires CVS access to Savannah. Please install cvs."
    exit 1
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

#if ! ./build-readline.sh
#then
#    echo "Failed to build Readline"
#    exit 1
#fi

###############################################################################

echo ""
echo "========================================"
echo "================ Qemacs ================"
echo "========================================"

export CVSEDITOR=emacs
export CVSROOT="$PWD/qemacs"
mkdir -p "$CVSROOT"

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

if ! cvs -z3 -d:pserver:anonymous@cvs.savannah.nongnu.org:/sources/qemacs co qemacs;
then
    echo "Failed to download QEmacs"
    exit 1
fi

cd "$QEMACS_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/qemacs.patch ]]; then
    patch -u -p0 < ../patch/qemacs.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo "**********************"
echo "Configuring package"
echo "**********************"

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
    --disable-x11 \
    --disable-ffmpeg

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure QEmacs"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS}"
then
    echo "Failed to build QEmacs"
    exit 1
fi

# Fix flags in .pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

#echo "**********************"
#echo "Testing package"
#echo "**********************"

#MAKE_FLAGS="check"
#if ! "${MAKE}" "${MAKE_FLAGS}"
#then
#    echo ""
#    echo "Failed to test QEmacs"
#    echo ""
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
    ARTIFACTS=("$QEMACS_TAR" "$QEMACS_DIR")
    for artifact in "${ARTIFACTS}"; do
        rm -rf "$artifact"
    done
fi

exit 0
