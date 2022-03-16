#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Ncurses from sources. We do not
# build Termcap, so there is no libtinfo{w}.

# Do NOT use Ncurses 6.2. There are too many problems with the release.
# Ncurses 6.2 does not build. It ends in a compile error. Additionally,
# the patches supplied for Ncurses 6.2 do not apply.
#
# We must wait for the Ncurses 6.3 release.
#
# Linux from Scratch provides a lot of cool hints for building Ncurses.
# Also see the following for Ncurses 6.1:
#   http://www.linuxfromscratch.org/lfs/view/9.0-systemd/chapter06/ncurses.html
# And for Ncurses 6.2:
#   http://www.linuxfromscratch.org/lfs/view/development/chapter06/ncurses.html

NCURSES_VER=6.3
NCURSES_TAR="ncurses-${NCURSES_VER}.tar.gz"
NCURSES_DIR="ncurses-${NCURSES_VER}"
PKG_NAME=ncurses

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

# Remove old Termcap/libtinfo{w}
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S find ${INSTX_LIBDIR} -name 'libtinfo*' -exec rm -f {} \;
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S find ${INSTX_PREFIX}/include -name 'termcap*' -exec rm -f {} \;
else
    find ${INSTX_LIBDIR} -name 'libtinfo*' -exec rm -f {} \;
    find ${INSTX_PREFIX}/include -name 'termcap*' -exec rm -f {} \;
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Ncurses ==============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

# Remove all the old shit from testing
rm -rf ncurses-6.*

if ! "$WGET" -q -O "$NCURSES_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR"
then
    echo "Failed to download Ncurses"
    exit 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR" || exit 1

# Don't attempt to apply patches. They don't apply. Sigh...
if false; then

# https://invisible-island.net/ncurses/ncurses.faq.html#applying_patches
if "$WGET" -q -O dev-patches.zip --ca-certificate="$LETS_ENCRYPT_ROOT" \
   "ftp://ftp.invisible-island.net/ncurses/${NCURSES_VER}/dev-patches.zip"
then
    if unzip dev-patches.zip -d .
    then
        echo "********************************"
        echo "Applying Ncurses patches"
        echo "********************************"
        for p in ncurses-${NCURSES_VER}-*.patch.gz ;
        do
            echo "Applying ${p}"
            zcat "${p}" | patch -s -p1
        done
    else
        echo "********************************"
        echo "Failed to unpack Ncurses patches"
        echo "********************************"
        exit 1
    fi
else
    echo "**********************************"
    echo "Failed to download Ncurses patches"
    echo "**********************************"
    exit 1
fi

fi

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/ncurses${NCURSES_VER}.patch ]]; then
    echo ""
    echo "***************************"
    echo "Patching package"
    echo "***************************"

    patch -u -p0 < ../patch/ncurses${NCURSES_VER}.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo ""
echo "***************************"
echo "Configuring package"
echo "***************************"

# We always build the wide version of Ncurses via --enable-widec.

CONFIG_OPTS=()
CONFIG_OPTS+=("--disable-leaks")
CONFIG_OPTS+=("--with-shared")
CONFIG_OPTS+=("--with-cxx-shared")
CONFIG_OPTS+=("--enable-widec")
CONFIG_OPTS+=("--without-debug")
# CONFIG_OPTS+=("--with-termlib")
CONFIG_OPTS+=("--enable-pc-files")
CONFIG_OPTS+=("--disable-root-environ")
CONFIG_OPTS+=("--with-pkg-config-libdir=${INSTX_PKGCONFIG}")

# Distros move this directory around
if [[ -d "/etc/terminfo" ]]; then
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/etc/terminfo")
elif [[ -d "/usr/lib64/terminfo" ]]; then
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/lib64/terminfo")
elif [[ -d "/usr/lib/terminfo" ]]; then
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/lib/terminfo")
elif [[ -d "/lib64/terminfo" ]]; then
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/lib64/terminfo")
elif [[ -d "/lib/terminfo" ]]; then
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/lib/terminfo")
else
    # This is $DATADIR/terminfo
    CONFIG_OPTS+=("--with-default-terminfo-dir=${INSTX_PREFIX}/share/terminfo")
fi


if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    ncurses_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${NCURSES_DIR}"
    ncurses_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${NCURSES_DIR}"
else
    ncurses_cflags="${INSTX_CFLAGS}"
    ncurses_cxxflags="${INSTX_CXXFLAGS}"
fi

    # Ncurses use PKG_CONFIG_LIBDIR, not PKG_CONFIG_PATH???
    PKG_CONFIG_LIBDIR="${INSTX_PKGCONFIG}" \
    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${ncurses_cflags}" \
    CXXFLAGS="${ncurses_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${INSTX_LDLIBS}" \
    LIBS="${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***************************"
    echo "Failed to configure Ncurses"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

# Remove unneeded warnings
IFS= find "$PWD" -name 'Makefile' -print | while read -r file
do
    sed -e 's/ --param max-inline-insns-single=1200//g' \
        -e 's/ -no-cpp-precomp//g' \
        "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod u=rw,go=r "$file"
done

echo ""
echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-j" "${INSTX_JOBS}")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to build Ncurses"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("test")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***************************"
    echo "Failed to test Ncurses"
    echo "***************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***************************"
echo "Installing package"
echo "***************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${NCURSES_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash ../copy-sources.sh "${PWD}" "${INSTX_SRCDIR}/${NCURSES_DIR}"
fi

echo ""
echo "***************************"
echo "Extra commands"
echo "***************************"

# Extra commands to provide non-wide names for warez that needs them.
# Linux uses linker scripts, while non-linux uses soft links.
# http://www.linuxfromscratch.org/lfs/view/9.0-systemd/chapter06/ncurses.html
{
    echo '#!/usr/bin/env bash'
    echo ''

    echo "include_dir=${INSTX_PREFIX}/include"
    echo "lib_dir=${INSTX_LIBDIR}"

    echo ''
    echo 'cd ${lib_dir}'
    echo ''

# JW added ncurses++ and tinfo
if [[ "${IS_LINUX}" -eq 1 ]]; then

    echo 'for lib in ncurses ncurses++ form panel menu ; do'
    echo '    rm -vf                    ${lib_dir}/lib${lib}.so'
    echo '    rm -vf                    ${lib_dir}/lib${lib}.so.6'
    echo '    echo "INPUT(-l${lib}w)" > ${lib_dir}/lib${lib}.so'
    echo '    ln -sfv lib${lib}.so.6    ${lib_dir}/lib${lib}.so.6'
    echo 'done'
    echo ''

    echo 'rm -vf                     ${lib_dir}/libcursesw.so'
    echo 'rm -vf                     ${lib_dir}/libcurses.so'
    echo 'echo "INPUT(-lncursesw)" > ${lib_dir}/libcursesw.so'
    echo 'ln -sfv libncurses.so      ${lib_dir}/libcurses.so'
    echo ''

elif [[ "${IS_DARWIN}" -eq 1 ]]; then

    echo 'for lib in ncurses ncurses++ form panel menu ; do'
    echo '    rm -vf                       ${lib_dir}/lib${lib}.dylib'
    echo '    rm -vf                       ${lib_dir}/lib${lib}.6.dylib'
    echo '    ln -sfv lib${lib}w.dylib     ${lib_dir}/lib${lib}.dylib'
    echo '    ln -sfv lib${lib}w.6.dylib   ${lib_dir}/lib${lib}.6.dylib'
    echo 'done'
    echo ''

    echo 'rm -vf                     ${lib_dir}/libcursesw.dylib'
    echo 'rm -vf                     ${lib_dir}/libcurses.dylib'
    echo 'ln -sfv libcursesw.dylib   ${lib_dir}/libcurses.dylib'
    echo 'ln -sfv libncurses.dylib   ${lib_dir}/libcurses.dylib'
    echo ''

else

    echo 'for lib in ncurses ncurses++ form panel menu ; do'
    echo '    rm -vf                    ${lib_dir}/lib${lib}.so'
    echo '    rm -vf                    ${lib_dir}/lib${lib}.so.6'
    echo '    ln -sfv lib${lib}w.so     ${lib_dir}/lib${lib}.so'
    echo '    ln -sfv lib${lib}w.so.6   ${lib_dir}/lib${lib}.so.6'
    echo 'done'
    echo ''

    echo 'rm -vf                     ${lib_dir}/libcursesw.so'
    echo 'rm -vf                     ${lib_dir}/libcurses.so'
    echo 'ln -sfv libcursesw.so      ${lib_dir}/libcurses.so'
    echo 'ln -sfv libncurses.so      ${lib_dir}/libcurses.so'
    echo ''
fi

    echo ''
    echo 'cd ${lib_dir}/pkgconfig'
    echo ''

    echo 'for lib in ncurses ncurses++ form panel menu ; do'
    echo '    rm -vf                  ${lib_dir}/pkgconfig/${lib}.pc'
    echo '    ln -sfv ${lib}w.pc      ${lib_dir}/pkgconfig/${lib}.pc'
    echo 'done'
    echo ''

    echo ''
    echo 'cd ${include_dir}'
    echo ''
    echo 'ln -sfv ncursesw      ${include_dir}/ncurses'

} > extra-cmds.sh

# Run the extra commands...
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash extra-cmds.sh
else
    bash extra-cmds.sh
fi

# Fix permissions once
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

###############################################################################

touch "${INSTX_PKG_CACHE}/${PKG_NAME}"

cd "${CURR_DIR}" || exit 1

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$NCURSES_TAR" "$NCURSES_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
