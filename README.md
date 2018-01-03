# Build-Scripts
This GitHub is a collection of build scripts useful when building and testing programs and libraries on downlevel and unique clients. It should result in working SSH, Wget, cURL and Git clients on systems like Fedora 10, CentOS 5 and Solaris 11. After you have a modern Git and Wget you can usually test your software as desired.

The general idea of the scripts are, you want to run `./build-wget.sh`, `./build-ssh.sh`, `./build-git.sh` or some other program build script. The build script for the program will download an build the dependent libraries for the program (even if the library was previously built before). You can build a library yourself, but you need to make sure the dependents are built in the case of a library (only programs build dependencies for you).

The scripts should mostly work on AIX, Android, BSDs, Cygwin, iOS, Linux, OS X and Solaris. GnuTLS is included but it is mostly experimental/non-working at the moment due to problems with dependencies like Guile.

Adding a new library script is mostly copy and paste. Start with `build-zlib.h`, copy/paste it to a new file, and then add the necessary pieces for the library. Program scripts are copy and paste too, but they are also more involved because you have to tend to the dependent libraries. See `./build-ssh.sh` as an example because its small.

# Output Artifacts
All artifacts are placed in `/usr/local` by default with runtime paths and dtags set to the proper library location. The proper library location on 32-bit machines is `/usr/local/lib`; while 64-bit systems use `/usr/local/lib` (Debian and derivatives) or `/usr/local/lib64` (Red Hat and derivatives).

You can override the install locations with `INSTALL_PREFIX` and `INSTALL_LIBDIR`. `INSTALL_PREFIX` is passed as `--prefix` to Autotools projects, and `INSTALL_LIBDIR` is passed as `--libdir` to Autotools projects. Non-Autotools projects get patched after unpacking (see build-bzip.sh for an example). For example:

```
# Build and install using the directories described above
./build-wget.sh

# Build and install in a temp directory
INSTALL_PREFIX="$HOME/tmp" ./build-wget.sh

# Build and install in a temp directory (same as the first command, but not obvious)
INSTALL_PREFIX="$HOME/tmp" INSTALL_LIBDIR="$INSTALL_PREFIX/tmp/lib" ./build-wget.sh

# Build and install in a temp directory and use and different library path
INSTALL_PREFIX="$HOME/tmp" INSTALL_LIBDIR="$HOME/mylibs" ./build-wget.sh
```

# Boot strapping
A basic order should be followed. Older systems like CentOS 5 are more sensitive than newer systems. First, run `build-cacerts.sh` to install several CAs in `$HOME/.cacerts`. Second, run `build-autotools.sh`, which should bring Autotools up to date. After CA have been installed and Autotools updated you should be mostly OK.

Wget should be built next when working on older systems. CentOS 5 provides Wget 1.11, and it does not support SNI (SNI support did not arrive until Wget 1.14). The old Wget will fail to download cURL which Git needs for its build. The cURL download fails due to shared hosting and lack of SNI.

Be sure to run `hash -r` after installing new programs to invalidate the Bash program cache. Otherwise old programs may be used.

# Authenticity
The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver authentic tarballs. `build-cacerts.sh` and `build-wget.sh` are enough to ensure the correct CAs and Wget are available to bootstrap the process with minimal risk.

It is unfortunate GNU does not run their own PKI and have their own CA. More risk could be eliminated if we only needed to trust the GNU organization and their root certificate.

# Bugs

If you find a bug then submit a patch or raise a bug report.

If you experience a failure like `reset` failing in your shell:

```
$ reset
reset: error while loading shared libraries: libtinfow.so.6:
Cannot open shared object file: No such file or directory
```

Then build Ncurses again with `./build-ncurses.sh`. `reset` will work again after building and installing Ncurses.

The failure is unexplained at the moment, but the scripts are probably doing something wrong, like building Termcap, GetText or Ncurses in the wrong order for a program like cURL or Git.
