#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Git and its dependencies from sources.

GIT_VER=2.38.0
GIT_TAR="git-${GIT_VER}.tar.gz"
GIT_DIR="git-${GIT_VER}"
PKG_NAME=git

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
    echo "Failed to install CA certs"
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

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

if ! ./build-curl.sh
then
    echo "Failed to build cURL"
    exit 1
fi

###############################################################################

# Needed for the pager used with 'git diff'
if ! ./build-less.sh
then
    echo "Failed to build less"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Git =================="
echo "========================================"

# Required. For Solaris see https://community.oracle.com/thread/1915569.
if ! perl -MExtUtils::MakeMaker -e1 2>/dev/null
then
    echo ""
    echo "Git requires Perl's ExtUtils::MakeMaker."
    echo "To fix this issue, please install ExtUtils-MakeMaker."
    exit 1
fi

echo ""
echo "***********************"
echo "Downloading package"
echo "***********************"

echo ""
echo "Git ${GIT_VER}..."

if ! "${WGET}" -q -O "$GIT_TAR" --ca-certificate="${THE_CA_ZOO}" \
     "https://mirrors.edge.kernel.org/pub/software/scm/git/$GIT_TAR"
then
    echo "Failed to download Git."
    exit 1
fi

rm -rf "$GIT_DIR" &>/dev/null
gzip -d < "$GIT_TAR" | tar xf -
cd "$GIT_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/git.patch ]]; then
    echo ""
    echo "***********************"
    echo "Patching package"
    echo "***********************"

    patch -u -p0 < ../patch/git.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash "${INSTX_TOPDIR}/fix-configure.sh"

echo ""
echo "***********************"
echo "Configuring package"
echo "***********************"

# Solaris 11.3 no longer has /usr/ucb/install
if [[ "$IS_SOLARIS" -ne 0 ]]
then

    IFS= find "$PWD" -type f -iname 'config*' -print | while read -r file
    do
        touch -a -m -r "$file" "$file.timestamp"
        chmod u+w "$file" && cp -p "$file" "$file.fixed"

        sed -e 's/\/usr\/ucb\///g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"

        chmod a+x "$file" && chmod go-w "$file"
        touch -a -m -r "$file.timestamp" "$file"
        rm "$file.timestamp"
    done
fi

if [[ "${INSTX_DEBUG_MAP}" -eq 1 ]]; then
    git_cflags="${INSTX_CFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GIT_DIR}"
    git_cxxflags="${INSTX_CXXFLAGS} -fdebug-prefix-map=${PWD}=${INSTX_SRCDIR}/${GIT_DIR}"
else
    git_cflags="${INSTX_CFLAGS}"
    git_cxxflags="${INSTX_CXXFLAGS}"
fi

if [[ -e /usr/local/bin/perl ]]; then
    GIT_PERL=/usr/local/bin/perl
elif [[ -e /usr/bin/perl ]]; then
    GIT_PERL=/usr/bin/perl
else
    GIT_PERL=perl
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-pthreads")
CONFIG_OPTS+=("--without-tcltk")

if [[ "${IS_SOLARIS}" -eq 1 ]]; then
    CONFIG_OPTS+=("ac_cv_func_inet_ntop=yes")
    CONFIG_OPTS+=("ac_cv_func_inet_pton=yes")
fi

    CURLDIR="${INSTX_PREFIX}" \
    CURL_CONFIG="${INSTX_PREFIX}/bin/curl-config" \
    PKG_CONFIG_PATH="${INSTX_PKGCONFIG}" \
    CPPFLAGS="${INSTX_CPPFLAGS} -DNO_UNALIGNED_LOADS=1" \
    ASFLAGS="${INSTX_ASFLAGS}" \
    CFLAGS="${git_cflags}" \
    CXXFLAGS="${git_cxxflags}" \
    LDFLAGS="${INSTX_LDFLAGS}" \
    LIBS="-lssl -lcrypto -lz ${INSTX_LDLIBS}" \
./configure \
    --build="${AUTOCONF_BUILD}" \
    --prefix="${INSTX_PREFIX}" \
    --libdir="${INSTX_LIBDIR}" \
    --with-lib="$(basename "${INSTX_LIBDIR}")" \
    --with-sane-tool-path="${INSTX_PREFIX}/bin" \
    --with-openssl="${INSTX_PREFIX}" \
    --with-curl="${INSTX_PREFIX}" \
    --with-libpcre="${INSTX_PREFIX}" \
    --with-zlib="${INSTX_PREFIX}" \
    --with-iconv="${INSTX_PREFIX}" \
    --with-expat="${INSTX_PREFIX}" \
    --with-perl="$GIT_PERL" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo ""
    echo "***********************"
    echo "Failed to configure Git"
    echo "***********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix LD_LIBRARY_PATH and DYLD_LIBRARY_PATH
bash ../fix-library-path.sh

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("-j" "${INSTX_JOBS}" "V=1")

# Disables GUI if TCL is missing.
if [[ -z "$(command -v tclsh 2>/dev/null)" ]]; then
   MAKE_FLAGS+=("NO_TCLTK=Yes")
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash "${INSTX_TOPDIR}/fix-makefiles.sh"

echo ""
echo "***********************"
echo "Building package"
echo "***********************"

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***********************"
    echo "Failed to build Git"
    echo "***********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix flags in *.pc files
bash "${INSTX_TOPDIR}/fix-pkgconfig.sh"

# Fix runpaths
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Testing package"
echo "***********************"

MAKE_FLAGS=("test" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo ""
    echo "***********************"
    echo "Failed to test Git"
    echo "***********************"

    bash "${INSTX_TOPDIR}/collect-logs.sh" "${PKG_NAME}"
    exit 1
fi

# Fix runpaths again
bash "${INSTX_TOPDIR}/fix-runpath.sh"

echo ""
echo "***********************"
echo "Installing package"
echo "***********************"

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("install")

if [[ -n "${SUDO_PASSWORD}" ]]; then
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    printf "%s\n" "${SUDO_PASSWORD}" | sudo ${SUDO_ENV_OPT} -S bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GIT_DIR}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    bash "${INSTX_TOPDIR}/fix-permissions.sh" "${INSTX_PREFIX}"
    bash "${INSTX_TOPDIR}/copy-sources.sh" "${PWD}" "${INSTX_SRCDIR}/${GIT_DIR}"
fi

###############################################################################

if [[ -z "$(git config --get http.sslCAInfo)" ]];
then
    echo ""
    echo "*****************************************************************************"
    echo "Configuring Git to use CA store at $INSTX_CACERT_FILE"
    echo "*****************************************************************************"

    git config --global http.sslCAInfo "$INSTX_CACERT_FILE"
else
    echo ""
    echo "*****************************************************************************"
    echo "Git already configured to use CA store at $(git config --get http.sslCAInfo)"
    echo "*****************************************************************************"
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
    ARTIFACTS=("$GIT_TAR" "$GIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
