#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Perl from sources.

# A modern Perl with some TextUtils and FindBin is needed by OpenSSL 1.1.x,
# but Perl is fragile. We can't install packages like HTTP unless it is in
# a magic directory like `/usr/local`. There's something broke with the cpan
# program that gets built. We need to keep an eye on what breaks due to Perl.

# This downloads and installs Perl's package manager. I'm not sure if we
# should do something with it. I'm not even sure if it uses our Perl or not.
#
#     curl -L http://cpanmin.us | perl - App::cpanminus

# Perl releases are even numbers. Don't install an odd-release number.

PERL_VER=5.32.1
PERL_TAR=perl-${PERL_VER}.tar.gz
PERL_DIR=perl-${PERL_VER}
PKG_NAME=perl

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip"
    exit 1
fi

###############################################################################

if ! ./build-base.sh
then
    echo "Failed to build GNU base packages"
    exit 1
fi

###############################################################################

if ! ./build-gdbm.sh
then
    echo "Failed to build GNU DB"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

###############################################################################

if [[ ! -f "$INSTX_PREFIX/bin/sed" ]]; then
    if ! ./build-sed.sh
    then
        echo "Failed to build Sed"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Perl ================="
echo "========================================"

echo ""
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@ Warning: Perl does not handle rpaths and runpaths properly. @@"
echo "@@ The wrong libraries will likely be loaded during runtime.   @@"
echo "@@ Also see https://github.com/Perl/perl5/issues/17534,        @@"
echo "@@ https://github.com/Perl/perl5/issues/18467, and             @@"
echo "@@ https://github.com/Perl/perl5/issues/18468.                 @@"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo ""
echo "************************"
echo "Downloading package"
echo "************************"

echo ""
echo "Perl ${PERL_VER}..."

if ! "${WGET}" -q -O "$PERL_TAR" --ca-certificate="${LETS_ENCRYPT_ROOT}" \
     "https://www.cpan.org/src/5.0/$PERL_TAR"
then
    echo "Failed to download Perl"
    exit 1
fi

rm -rf "$PERL_DIR" &>/dev/null
gzip -d < "$PERL_TAR" | tar xf -
cd "$PERL_DIR" || exit 1

#cp op.c op.c.orig
#cp pp.c pp.c.orig
#cp sv.c sv.c.orig
#cp numeric.c numeric.c.orig
#cp regcomp.c regcomp.c.orig
#cp vms/vms.c vms/vms.c.orig
#cp ext/POSIX/POSIX.xs ext/POSIX/POSIX.xs.orig
#cp cpan/Compress-Raw-Zlib/zlib-src/zutil.c cpan/Compress-Raw-Zlib/zlib-src/zutil.c.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/perl.patch ]]; then
    chmod a+w op.c pp.c sv.c numeric.c regcomp.c vms/vms.c
    chmod a+w ext/POSIX/POSIX.xs
    chmod a+w cpan/Compress-Raw-Zlib/zlib-src/zutil.c

    echo ""
    patch -u -p0 < ../patch/perl.patch

    chmod a-w op.c pp.c sv.c numeric.c regcomp.c vms/vms.c
    chmod a-w ext/POSIX/POSIX.xs
    chmod a-w cpan/Compress-Raw-Zlib/zlib-src/zutil.c
fi

#diff -u op.c.orig op.c > ../patch/perl.patch
#diff -u pp.c.orig pp.c >> ../patch/perl.patch
#diff -u sv.c.orig sv.c >> ../patch/perl.patch
#diff -u numeric.c.orig numeric.c >> ../patch/perl.patch
#diff -u regcomp.c.orig regcomp.c >> ../patch/perl.patch
#diff -u vms/vms.c.orig vms/vms.c >> ../patch/perl.patch
#diff -u ext/POSIX/POSIX.xs.orig ext/POSIX/POSIX.xs >> ../patch/perl.patch
#diff -u cpan/Compress-Raw-Zlib/zlib-src/zutil.c.orig cpan/Compress-Raw-Zlib/zlib-src/zutil.c >> ../patch/perl.patch

# Perl creates files in the user's home directory, but owned by root:root.
# It looks like they are building shit during 'make install'. WTF???
# Note to future maintainers: never build shit during 'make install'.
mkdir -p "$HOME/.cpan"

echo ""
echo "************************"
echo "Configuring package"
echo "************************"

# The HTTP gear breaks on all distros, like Ubuntu 4 and Fedora 32
# https://www.nntp.perl.org/group/perl.beginners/2020/01/msg127308.html
# -Dextras="HTTP::Daemon HTTP::Request Test::More Text::Template"

# CPAN uses Make rather than Gmake. It breaks on some of the BSDs.
# Also see https://github.com/Perl/perl5/issues/17543.
export MAKE="${MAKE}"

# More broken Perl shit... Mishandling of $ORIGIN requires this shit...
# https://metacpan.org/pod/distribution/perl/INSTALL#Dynamic-Loading
OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
OLD_DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH"
OLD_SHLIB_PATH="$SHLIB_PATH"
OLD_LIBPATH="$LIBPATH"

# Strip duplicate, leading and trailing colons
LD_LIBRARY_PATH=$(echo "$INSTX_LIBDIR:$LD_LIBRARY_PATH" | tr -s ':' | sed -e 's/^:\(.*\)/\1/' | sed -e 's/:$//g')
DYLD_LIBRARY_PATH=$(echo "$INSTX_LIBDIR:$DYLD_LIBRARY_PATH" | tr -s ':' | sed -e 's/^:\(.*\)/\1/' | sed -e 's/:$//g')
SHLIB_PATH=$(echo "$INSTX_LIBDIR:$SHLIB_PATH" | tr -s ':' | sed -e 's/^:\(.*\)/\1/' | sed -e 's/:$//g')
LIBPATH=$(echo "$INSTX_LIBDIR:$LIBPATH" | tr -s ':' | sed -e 's/^:\(.*\)/\1/' | sed -e 's/:$//g')
export LD_LIBRARY_PATH DYLD_LIBRARY_PATH SHLIB_PATH LIBPATH

# And More broken Perl shit... Why can't the build system do this itself???
export PERL5LIB="$PWD/lib"

# And even more broken Perl shit. Perl munges -Wl,-R,'$ORIGIN/../lib'.
# Somehow it manages to escape the '$ORIGIN/../lib' in single quotes.
# Set it to something it does not mishandle, and then fix it later.
# Also see https://github.com/Perl/perl5/issues/17534.
export ORIGIN="ABCDE_ORIGIN_VWXYZ"

# Don't use Perl versions of zLib or Bzip2. Perl versions are old and
# have outstanding CVEs. Our versions are new and hardened. Also see
# http://www.linuxfromscratch.org/lfs/view/development/chapter08/perl.html
export BUILD_ZLIB=0 BUILD_BZIP2=0

# And more broken Perl shit on OS X.
# https://stackoverflow.com/q/32280732
if [[ "${OSX_10p5_OR_10p6}" -eq 1 ]]; then
    echo "Fixing Perl's MACOSX_DEPLOYMENT_TARGET"
    filename=hints/darwin.sh
    chmod +w "${filename}"
    sed 's/MACOSX_DEPLOYMENT_TARGET=10.3/MACOSX_DEPLOYMENT_TARGET=10.5/g' "${filename}" > "${filename}.fixed"
    mv "${filename}.fixed" "${filename}"
    chmod -w "${filename}"
fi

if [[ "${INSTX_LIBM}" -eq 1 ]]; then
    opt_libm="-lm"
fi

    CC="${CC}" \
    CXX="${CXX}" \
    PKGCONFIG="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS}" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${INSTX_CFLAGS}" \
    CXXFLAGS="${INSTX_CXXFLAGS}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LDLIBS="${opt_libm} ${INSTX_LDLIBS}" \
    LIBS="${opt_libm} ${INSTX_LDLIBS}" \
./Configure -des \
    -Dprefix="${INSTX_PREFIX}" \
    -Dlibdir="${INSTX_LIBDIR}" \
    -Dlocincpth="${INSTX_PREFIX}/include" \
    -Dloclibpth="${INSTX_LIBDIR}" \
    -Dpkgconfig="${INSTX_PKGCONFIG}" \
    -Dcc="${CC}" \
    -Dcxx="${CXX}" \
    -Acppflags="${INSTX_CPPFLAGS}" \
    -Aasflags="${INSTX_ASFLAGS}" \
    -Accflags="${INSTX_CPPFLAGS} ${INSTX_CFLAGS}" \
    -Acxxflags="${INSTX_CPPFLAGS} ${INSTX_CXXFLAGS}" \
    -Aldflags="${INSTX_LDFLAGS}" \
    -Aldlibs="${opt_libm} ${INSTX_LDLIBS}" \
    -Alibs="${opt_libm} ${INSTX_LDLIBS}" \
    -Duseshrplib \
    -Dusethreads \
    -Dextras="FindBin Text::* Util::* ExtUtils::* Term::* Test::* HTTP::*"
    # -Dextras="FindBin Text::Template Test::More HTTP::Daemon HTTP::Request"

if [[ "$?" -ne 0 ]]; then
    echo "************************"
    echo "Failed to configure Perl"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

echo ""
echo "******************************"
echo "Fixing config.sh and Makefiles"
echo "******************************"

# Thanks to @tonycoz on the Perl bug tracker.
# https://github.com/Perl/perl5/issues/18466

origin_good=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin_bad=$(echo 'ABCDE_ORIGIN_VWXYZ/' | sed -e 's/[\/&]/\\&/g')

miniperl_good=$(echo '$(miniperl_objs) $(libs)')
miniperl_bad=$(echo '$(miniperl_objs) $(libs)')

IFS= find "./" \( -name 'config.sh' -o -name 'Makefile' \) -print | while read -r file
do
    # Display filename, strip leading "./"
    echo "$file" | tr -s '/' | cut -c 3-

    touch -a -m -r "$file" "$file.timestamp"
    chmod a+w "$file"

    sed -e "s/$origin_bad/$origin_good/g" \
        -e "s/$miniperl_bad/$miniperl_good/g" \
        -e "s/ -no-cpp-precomp//g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"

    # Need a subshell. Regenerate the Makefile
    (
        cd "$(dirname "${file}")"
        if [[ -f Makefile ]]; then
            ${MAKE} Makefile 2>/dev/null
        fi
    )

    chmod go-w "$file"
    touch -a -m -r "$file.timestamp" "$file"
    rm "$file.timestamp"
done

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
# Not needed due to @tonycoz's workarounds.
# bash "${INSTX_TOPDIR}/fix-makefiles.sh"

# porting/exec-bit.t failure after fix-makefiles.sh
# chmod a+x ./Makefile.SH;

echo ""
echo "************************"
echo "Building package"
echo "************************"

# Perl has a problem with parallel builds on some paltforms.
if [[ "$IS_NETBSD" -eq 1 ]]; then
    MAKE_FLAGS=("-j" "1")
else
    MAKE_FLAGS=("-j" "${INSTX_JOBS}")
fi

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "************************"
    echo "Failed to build Perl"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo "************************"
echo "Testing package"
echo "************************"

MAKE_FLAGS=("check" "-j" "1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "************************"
    echo "Failed to test Perl"
    echo "************************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

# Restore for the braindead installer
export LD_LIBRARY_PATH="$OLD_LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$OLD_DYLD_LIBRARY_PATH"
export SHLIB_PATH="$OLD_LD_SHLIB_PATH"
export LIBPATH="$OLD_LIBPATH"

echo ""
echo "************************"
echo "Installing package"
echo "************************"

MAKE_FLAGS=("install")
if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
fi

# printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S chown -R "$SUDO_USER:$SUDO_USER" "$HOME/.cpan"

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
    ARTIFACTS=("$PERL_TAR" "$PERL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
