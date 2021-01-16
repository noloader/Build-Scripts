# Build-Scripts

This GitHub is a collection of build scripts useful for building and testing programs and libraries on downlevel clients and clients where program updates are not freely available. It should result in working SSH, Wget, cURL and Git clients on systems like PowerMac G5, Fedora 1, Ubuntu 4, CentOS 5 and Solaris 11.

The general idea of the scripts are, you run `./build-wget.sh`, `./build-ssh.sh`, `./build-git.sh` or some other script to get a fresh tool. The script for the program will download and build the dependent libraries for the program. When the script completes you have a working tool in `/usr/local` or `/opt/local` on the BSDs.

Some recipes only work on modern platforms. For example, GNU SIP Witch may not build on a PowerMac G5. It is a small loss since most organizations will not run a SIP server on antique hardware.

## Setup

Once you clone the repo you should perform a one-time setup. The setup installs updated CA certificates and builds a modern Wget. `setup-cacerts.sh` installs a local copy of 11 CA certificates in `$HOME/.build-scripts/cacerts`. They are used to download source code packages for programs and libraries. `setup-wget.sh` installs a local copy of `wget` in `$HOME/.build-scripts/wget`. It is a reduced-functionality version of Wget with only HTTPS, IPv4, IPv6 and large-file support. It is anemic but functional enough to download packages over HTTPS.

```
$ ./setup-cacerts.sh
...

$ ./setup-wget.sh
...
```

You can verify Wget bootstrap with the following commands.

```
$ $HOME/.build-scripts/wget/bin/openssl version
OpenSSL 1.0.2u  20 Dec 2019

$ $HOME/.build-scripts/wget/bin/wget --version
GNU Wget 1.20.3 built on solaris2.11.
```

The bootstrap version of Wget uses OpenSSL 1.0.2. OpenSSL 1.0.2 is now end-of-life and will accumulate unfixed bugs. We cannot upgrade to OpenSSL 1.1.x because of a Perl dependency. OpenSSL 1.1.x requires Perl 5.24, and Perl 5.24 is too new for some of the older systems.

On ancient systems, like Fedora 1 and Ubuntu 4, you will need to build Bash immediately. Ancient Bash does not work well with these scripts. Nearly all other systems have a new enough version of Bash.

## Output Artifacts

Artifacts are placed in `/usr/local` by default with runtime paths and dtags set to the proper library location. The library location on 32-bit machines is `/usr/local/lib`. 64-bit systems use `/usr/local/lib` (Debian and derivatives) or `/usr/local/lib64` (Red Hat and derivatives). The BSDs use `/opt/local` by default to avoid mixing libraries with system libraries in `/usr/local`.

You can override the install locations with `INSTX_PREFIX` and `INSTX_LIBDIR`. `INSTX_PREFIX` is passed as `--prefix` to Autotools projects, and `INSTX_LIBDIR` is passed as `--libdir` to Autotools projects. Non-Autotools projects get patched after unpacking (see `build-bzip.sh` for an example).

Examples of running the scripts and changing variables are shown below:

```
# Build and install using the directories described above
./build-wget.sh

# Build and install in a temp directory
INSTX_PREFIX="$HOME/tmp" ./build-wget.sh
```

## Source Code

The source code for a package can be installed if you need to perform debugging after installation. However, most recipes do not install the source code.

If you wish to install the source code for a package, then follow the `build-bash.sh` recipe. The script adds `-fdebug-prefix-map` to `CFLAGS` and `CXXFLAGS`, and then calls `copy-sources.sh` during install. `copy-sources.sh` copies headers and source files into `$INSTX_PREFIX/src`, and the script preserves the destination directory structure.

Once the sources are installed, the debugger works as expected.

```bash
(gdb) run
...
Program received signal SIGSEGV, Segmentation fault.
0x00005555556fd300 in internal_malloc (n=n@entry=0x20, file=file@entry=0x0,
    line=line@entry=0x0, flags=flags@entry=0x2) at malloc.c:824
824	{
(gdb) list
819	static PTR_T
820	internal_malloc (n, file, line, flags)		/* get a block */
821	     size_t n;
822	     const char *file;
823	     int line, flags;
824	{
825	  register union mhead *p;
826	  register int nunits;
827	  register char *m, *z;
828	  long nbytes;
(gdb)
```

## Runtime Paths

The build scripts attempt to set runtime paths in everything it builds. For example, on Fedora x86_64 the `LDFLAGS` include `-L/usr/local/lib64 -Wl,-R,/usr/local/lib64 -Wl,--enable-new-dtags`. `new-dtags` ensures a `RUNPATH` is used (as opposed to `RPATH`), and `RUNPATH` allows `LD_LIBRARY_PATH` overrides at runtime. The `LD_LIBRARY_PATH` support is important so self tests can run during `make check`.

If all goes well you will not suffer the stupid path problems that have plagued Linux for the last 25 years or so.

## Dependencies

Dependent libraries are minimally tracked. Once a library is built a file with the library name is `touch`'d in `$HOME/.build-scripts/$prefix`. Use of `$prefix` allows tracking of multiple installs. If the file is older than 7 days then the library is automatically rebuilt. Automatic rebuilding ensures newer versions of a library are used when available and sidesteps problems with trying to track version numbers.

Rebuilding after 7 days avoids a lot of package database bloat. As an example, MacPorts `registry.db` have been reported with sizes of 658,564,096, 744,112,128, 62,558,208 and 59,329,536. Also see [registry.db getting rather obese and updates very slow](https://lists.macports.org/pipermail/macports-users/2020-June/048510.html) on the MacPorts mailing list.

Programs are not tracked. When a script like `build-git.sh` or `build-ssh.sh` is run then the program is always built or rebuilt. The dependently libraries may (or may not) be built based the age, but the program is always rebuilt.

You can delete `$HOME/.build-scripts/$prefix` and all dependent libraries will be rebuilt on the next run of a build script.

## Authenticity

The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver authentic tarballs. `setup-cacerts.sh` and `setup-wget.sh` are enough to ensure the correct CAs and Wget are available to bootstrap the process with minimal risk.

It is unfortunate GNU does not run their own PKI and have their own CA. More risk could be eliminated if we only needed to trust the GNU organization and their root certificate.

## Build tools

In addition to a compiler, just about every package uses Autotools. Be sure to install autoconf, automake, libtool and pkg-config. And install Perl and Python if possible since many test suites use them.

The pkg-config package has several names, depending on the operating system. On Linux the package is `pkg-config` and sometimes `pkgconfig`. On other operating it may use the same name, or may use `pkgconf`.

## Sudo

If you want to install into a location like `/usr/local`, then you will need to provide your password. If you want to install into a location like `$HOME`, then you do not need to provide your password. Just press `ENTER` at the password prompt.

If you don't trust the code with your password then audit `setup-password.sh` and the use of `SUDO_PASSWORD`.

One thing the code does is the following, which could make the password available to programs like `ps`. The pattern is needed because `sudo -S` reads from `stdin` and requires a newline, but `echo` does not provide a newline on all platforms. Getting the newline with `printf` is the standard workaround on platforms like Solaris.

```
MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi
```

## Boehm GC

If you are building a program that requires Boehm GC then you need to install it from the distribution. Boehm GC is trickier than other packages because the correct version of the package for a particular distro must be downloaded. C++11 and libatomics further complicates the selection process. And an additional complication is alternate stacks and signals.

On Red Hat based systems you should install `gc-devel`. On Debian based systems you should install `libgc-dev`. If a package is not available then you should manually build the garbage collector.

If you attempt a manual build then `build-boehm-gc.sh` may work for you. But the script is pinned at Boehm-GC 7.2k to avoid C++11 dependencies. And the manual build may not integrate well if a program uses alternate stacks and signals.

## Documentation

The scripts avoid building documentation. If you need documentation then use the package's online documentation.

Documentation is avoided for several reasons. First, the documentation adds extra dependencies, like makeinfo, html2pdf, gtk and even Perl libraries. It is not easy to satisfy some dependencies, like those on a CentOS 5, Fedora 15 or Solaris system. The older systems, CentOS 5 and Fedora 15, don't even have working repos.

Second, the documentation wastes processing time. Low-end devices like ARM dev-boards can spend their compute cycles on more important things like compiling source code. Third, the documentation wastes space. Low-end devices like ARM dev-boards need to save space on their SDcards for more important things, like programs and libraires.

Fourth, and most importantly, the documentation complicates package building. Many packages assume a maintainer is building for a desktop system with repos packed full of everything needed. And reconfiguring with `--no-docs` or `--no-gtk-doc` often requires a `bootstrap` or `autoreconf` which requires additional steps and additional dependencies.

## Sanitizers

One of the benefits of using the build scripts is, you can somewhat easily build programs and dependent libraries using tools like Address Sanitizer (Asan), Undefined Behavior Sanitizer (UBsan) and GCC 10's Analyzer. Only minor modifications are necessary.

First, decide on a directory to sandbox the build. As an example, `/var/sanitize`:

```
INSTX_PREFIX=/var/sanitize
```

Second, use one of the following variables to enable a sanitizer:

* `INSTX_UBSAN=1`
* `INSTX_ASAN=1`
* `INSTX_MSAN=1`
* `INSTX_ANALYZE=1`

Finally, build and test the program or library as usual. For example, to build OpenSSL, perform:

```
INSTX_UBSAN=1 INSTX_PREFIX=/var/sanitize ./build-openssl.sh
```

Many programs and libraries feel it is OK to leak resources, and it screws up a lot testing. If you are using Asan or Msan and encounter too many `ERROR: LeakSanitizer: detected memory leaks`, then you may need `LSAN_OPTIONS=detect_leaks=0`. Also see [Issue 719, Suppress leak checking on exit](https://github.com/google/sanitizers/issues/719).

Once finished with testing perform `rm -rf /var/sanitize` so everything is deleted.

## Self Tests

The scripts attempt to run the program's or library's self tests. Usually the recipe is `make check`, but it is `make test` on occasion. If the self tests are run and fails, then the script stops before installation.

You have three choices on self-test failure. First, you can ignore the failure, `cd` into the program's directory, and then run `sudo make install`. Second, you can fix the failure, `cd` into the program's directory, run `make`, run `make check`, and then run `sudo make install`.

Third, you can open the `build-prog.sh` script, comment the portion that runs `make check`, and then run the script again. Some libraries, like OpenSSL, use this strategy since the self tests don't work as expected on several platforms.

## Git History

This GitHub does not aim to provide a complete history of changes from Commit 0. Part of the reason is, `bootstrap/` has binary files and the history and objects gets rather large. When a tarball is updated in `bootstrap/` we try to reset history according to [git-clearHistory](https://gist.github.com/stephenhardy/5470814).

Resetting history may result in errors like the one below.

```
$ git checkout master -f && git pull
Already on 'master'
Your branch and 'origin/master' have diverged,
and have 1338 and 1 different commits each, respectively.
  (use "git pull" to merge the remote branch into yours)
fatal: refusing to merge unrelated histories
```

If you encounter it, then run `reset-repo.sh` or perform the following.

```
$ git fetch
$ git reset --hard origin/master
HEAD is now at 9a50195 Reset repository after OpenSSL 1.1.1d bump
```

## Problems

This section details some known problems and problem packages.

### Cruft over Time

Linux systems do not operate well with multiple versions of a library installed. For example, suppose you install a program in 2019, and the program installs Ncurses 6.0, Readline 7.0 and GetText 1.20. By the time 2020 or 2021 rolls around, Ncurses 6.1, Readline 8.0 and GetText 1.21 are built and installed. So you have new headers, new libraries and old libraries.

Programs and libraries will effectively stop building due to compile and link errors because Linux does not know how to manage side-by-side installations, like OS X, Solaris or Windows. Shared objects get moved to libmylibrary.so.old, and then links like libmylibrary.so are pointed at the old library even though new headers are present for the new library.

The fix is to delete the install directory and start over. A `rm -rf /usr/local/*` usually works well to reset things.

### sysmacros.h

Some older versions of `sysmacros.h` cause a broken compile due to `__THROW` on C functions. The system headers are actually OK, the problem is Gnulib. Gnulib sets `__THROW` to the unsupported `__attribute__ ((__nothrow__))` and it breaks the compile. Affected versions include the header supplied with Fedora 1. Also see [ctype.h:192: error: parse error before '{' token](https://lists.gnu.org/archive/html/bug-gnulib/2019-07/msg00059.html). (Gnulib did not fix their bug once it was reported).

If you encounter a build error *"error: parse error before '{' token"*, then open `/usr/include/sys/sysmacros.h` and add the following after the last include. The last include should be `<features.h>`.

```
#include <features.h>

/* Gnulib redefines __THROW to __attribute__ ((__nothrow__)) */
/* This GCC compiler cannot handle the attribute.            */
#ifndef __cplusplus
# undef __THROW
# define __THROW
#endif
```

### Autogen

It appears Autogen is no longer being maintained. It uses libraries that are no longer present, like `libintl_dgettext` and `libintl_gettext`. Expect about 20/24 self test failures.

We don't know if Autogen actually works in practice.

### Autotools

Autotools is its own special kind of hell. Autotools is a place where progammers get sent when they have behaved badly.

On new distros you should install Autotools from the distribution. The packages in the Autotools collection which should be installed through the distribution include:

* Aclocal
* Autoconf
* Automake
* Autopoint
* Libtool

The build scripts include `build-autotools.sh` but you should use it sparingly on old distros. Attempting to update Autotools creates a lot of incompatibility problems. For example, Aclocal and Acheader will complain about wrong versions. Autoconf won't be able to find its M4 macros even though M4, Autoconf, Automake and Libtool are freshly installed in `$prefix`. Libtool will fail to link a library that is present in the expected location. Etc, etc, etc.

### GhostScript

GhostScript is probably not going to build properly. The package needs its `configure.ac` and `Makefile.am` rewritten to handle user flags properly.

### GnuPG

GnuPG may break Git and code signing. There seems to be an incompatibility in the way GnuPG prompts for a password and the way Git expects a user to provide a password.

### GnuTLS

GnuTLS may or may not build and install correctly. It is a big recipe and Guile causes a fair amount of trouble on many systems.

GnuTLS uses private headers from libraries like Nettle, so things can go sideways if the wrong libraries are loaded at runtime.

### OpenBSD

OpenBSD has an annoyance:

```
Provide an AUTOCONF_VERSION environment variable, please
```

If you encounter the annoyance then set the variables to `*`:

```
AUTOCONF_VERSION=* AUTOMAKE_VERSION=* ./build-package.sh
```

### Perl

Perl is a constant source of problems, but it is needed by OpenSSL 1.1.x. Perl's build system does not honor our flags, removes hardening flags, does not handle runpaths properly, uses incorrect directories in its configuration, builds packages as root during `make install`, and fails to run due to missing `libperl.so`. Perl is mostly a lost cause.

Note to future maintainers: honor the user's flags. never build shit during `make install`.

## Bugs

If you find a bug then submit a patch or raise a bug report.
