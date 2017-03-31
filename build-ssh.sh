#!/usr/bin/env bash

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

# OpenSSH can only use OpenSSL 1.0.2
# https://groups.google.com/forum/#!topic/opensshunixdev/AlgfQvPIlQE
OPENSSL_TAR=openssl-1.0.2k.tar.gz
OPENSSL_DIR=openssl-1.0.2k
#OPENSSL_TAR=openssl-1.1.0e.tar.gz
#OPENSSL_DIR=openssl-1.1.0e

SSH_TAR=openssh-7.5p1.tar.gz
SSH_DIR=openssh-7.5p1

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11

###############################################################################

# Autotools on Solaris has an implied requirement for GNU gear
# Things fall apart without it.
if [[ -d "/usr/gnu/bin" ]]; then
	if [[ ! ("$PATH" == *"/usr/gnu/bin"*) ]]; then
		echo "Adding /usr/gnu/bin to PATH for Solaris"
		PATH="/usr/gnu/bin:$PATH"
	fi
fi

# I don't like doing this, but...
read -s -p "Please enter password for sudo: " SUDO_PASSWWORD
echo

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_LINUX=$(echo -n "$THIS_SYSTEM" | grep -i -c linux)
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c cygwin)
IS_MINGW=$(echo -n "$THIS_SYSTEM" | grep -i -c mingw)
IS_OPENBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c openbsd)
IS_DRAGONFLY=$(echo -n "$THIS_SYSTEM" | grep -i -c dragonfly)
IS_FREEBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c freebsd)
IS_NETBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c netbsd)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)

if [[ ("$IS_FREEBSD" -eq "1" || "$IS_OPENBSD" -eq "1" || "$IS_NETBSD" -eq "1" || "$IS_DRAGONFLY" -eq "1") ]]; then
	MAKE=gmake
elif [[ ("$IS_SOLARIS" -eq "1") ]]; then
	MAKE=$(which gmake 2>/dev/null | grep -v "no gmake" | head -1)
	if [[ (-z "$MAKE") && (-e "/usr/sfw/bin/gmake") ]]; then
		MAKE=/usr/sfw/bin/gmake
	fi
else
	MAKE=make
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
	IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -eq "1" ]]; then
	SH_KBITS=64
	SH_MARCH=-m64
	INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
	INSTALL_LIBDIR_DIR="lib64"
elif [[ "$IS_64BIT" -eq "1" ]]; then
	if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
		SH_KBITS=64
		SH_MARCH=-m64
		INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
		INSTALL_LIBDIR_DIR="lib"
	elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
		SH_KBITS=64
		SH_MARCH=-m64
		INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
		INSTALL_LIBDIR_DIR="lib64"
	else
		SH_KBITS=64
		SH_MARCH=-m64
		INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
		INSTALL_LIBDIR_DIR="lib"
	fi
else
	SH_KBITS=32
	SH_MARCH=-m32
	INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
	INSTALL_LIBDIR_DIR="lib"
fi

echo
echo "********** libdir **********"
echo
echo "Using libdir $INSTALL_LIBDIR"

###############################################################################

echo
echo "********** zLib **********"
echo

wget "http://www.zlib.net/$ZLIB_TAR" -O "$ZLIB_TAR"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to download zLib"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$ZLIB_DIR" &>/dev/null
tar -xzf "$ZLIB_TAR"
cd "$ZLIB_DIR"

SH_LDLIBS=("-ldl -lpthread")
SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")

CPPFLAGS="-I$INSTALL_PREFIX/include" CFLAGS="$SH_MARCH -DNDEBUG" CXXFLAGS="$SH_MARCH -DNDEBUG" \
	LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
	./configure --enable-shared --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to configure zLib"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to build zLib"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

echo "$SUDO_PASSWWORD" | sudo -S make install

cd ..

###############################################################################

echo
echo "********** OpenSSL **********"
echo

# wget on Ubuntu 16 cannot validate against Let's Encrypt certificate
wget "https://www.openssl.org/source/$OPENSSL_TAR" --no-check-certificate -O "$OPENSSL_TAR"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to download OpenSSL"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
tar -xzf "$OPENSSL_TAR"
cd "$OPENSSL_DIR"

# OpenSSL and enable-ec_nistp_64_gcc_128 option
IS_X86_64=$(uname -m 2>&1 | egrep -i -c "(amd64|x86_64)")
if [[ "$SH_KBITS" -eq "32" ]]; then IS_X86_64=0; fi

CONFIG=./config
CONFIG_FLAGS=("no-ssl2" "no-ssl3" "no-comp" "shared" "-DNDEBUG" "-Wl,-rpath,$INSTALL_LIBDIR"
		"--prefix=$INSTALL_PREFIX" "--openssldir=$INSTALL_PREFIX" "--libdir=$INSTALL_LIBDIR_DIR")
if [[ "$IS_X86_64" -eq "1" ]]; then
	CONFIG_FLAGS+=("enable-ec_nistp_64_gcc_128")
fi

KERNEL_BITS="$SH_KBITS" "$CONFIG" "${CONFIG_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to configure OpenSSL"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4 depend)
"$MAKE" "${MAKE_FLAGS[@]}"

MAKE_FLAGS=(-j 4)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to build OpenSSL"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

echo "$SUDO_PASSWWORD" | sudo -S make install_sw

cd ..

###############################################################################

echo
echo "********** OpenSSH **********"
echo

# https://savannah.gnu.org/bugs/?func=detailitem&item_id=26786
wget "http://ftp4.usa.openbsd.org/pub/OpenBSD/OpenSSH/portable/$SSH_TAR" --no-check-certificate -O "$SSH_TAR"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to download SSH"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

rm -rf "$SSH_DIR" &>/dev/null
tar -xzf "$SSH_TAR"
cd "$SSH_DIR"

SH_LDFLAGS=("$SH_MARCH" "-Wl,-rpath,$INSTALL_LIBDIR" "-L$INSTALL_LIBDIR")
SH_LDLIBS=("-lz" "-ldl" "-lpthread")

CPPFLAGS="-I$INSTALL_PREFIX/include" CFLAGS="$SH_MARCH -DNDEBUG" CXXFLAGS="$SH_MARCH -DNDEBUG" \
	LDFLAGS="${SH_LDFLAGS[@]}" LIBS="${SH_LDLIBS[@]}" \
	./configure --prefix="$INSTALL_PREFIX" --libdir="$INSTALL_LIBDIR" \
	--with-openssl-dir="$INSTALL_PREFIX" --with-zlib="$INSTALL_PREFIX"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to configure SSH"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(-j 4 all)
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne "0" ]]; then
	echo "Failed to build SSH"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

echo "$SUDO_PASSWWORD" | sudo -S make install

cd ..

###############################################################################

echo
echo "********** Cleanup **********"
echo

if true; then

	ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR" "$UNISTR_TAR" "$UNISTR_DIR" "$READLN_TAR" "$READLN_DIR"
			"$PCRE_TAR" "$PCRE_DIR" "$PCRE2_TAR" "$PCRE2_DIR" "$ZLIB_TAR" "$ZLIB_DIR"  "$BZ2_TAR" "$BZ2_DIR"
			"$IDN2_TAR" "$IDN2_DIR" "$ICONV_TAR" "$ICONV_DIR" "$CURL_TAR" "$CURL_DIR" "$GIT_TAR" "$GIT_DIR")

	for artifact in "${ARTIFACTS[@]}"; do
		rm -rf "$artifact"
	done

	# ./build-git.sh 2>&1 | tee build-git.log
	if [[ -e build-git.log ]]; then
		rm build-git.log
	fi
fi

[[ "$0" = "$BASH_SOURCE" ]] && exit 0 || return 0
