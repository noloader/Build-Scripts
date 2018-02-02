# Build-Scripts

This GitHub is a collection of build scripts useful when building and testing programs and libraries on downlevel and unique clients. It should result in working SSH, Wget, cURL and Git clients on systems like PowerMac G5, Fedora 10, CentOS 5 and Solaris 11. After you have a modern Git and Wget you can usually test your software as desired.

The general idea of the scripts are, you want to run `./build-wget.sh`, `./build-ssh.sh`, `./build-git.sh` or some other program build script. The build script for the program will download an build the dependent libraries for the program (even if the library was previously built before). When the script complete you ahve a working tool in `/usr/local`.

The scripts should mostly work on AIX, Android, BSDs, Cygwin, iOS, Linux, OS X and Solaris. GnuTLS is included but it is mostly experimental/non-working at the moment due to problems with dependencies like Guile.

Adding a new library script is mostly copy and paste. Start with `build-zlib.h`, copy/paste it to a new file, and then add the necessary pieces for the library. Program scripts are copy and paste too, but they are also more involved because you have to include dependent libraries. See `build-ssh.sh` as an example because it is small.

## Output Artifacts

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

## Boot strapping

A basic order may need to be followed. Older systems like CentOS 5 are more sensitive than newer systems. First, run `build-cacerts.sh` to install several CAs in `$HOME/.cacerts`. Second, if needed, run `build-autotools.sh`, which should bring Autotools up to date. Third, run `build-libtool.sh` to modernize Libtool. After CA have been installed and Autotools updated you should be mostly OK.

Wget should be built next when working on older systems. CentOS 5 provides Wget 1.11, and it does not support SNI (SNI support did not arrive until Wget 1.14). The old Wget will fail to download cURL which Git needs for its build. The cURL download fails due to shared hosting and lack of SNI.

Be sure to run `hash -r` after installing new programs to invalidate the Bash program cache. Otherwise old programs may be used.

## Authenticity

The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver authentic tarballs. `build-cacerts.sh` and `build-wget.sh` are enough to ensure the correct CAs and Wget are available to bootstrap the process with minimal risk.

It is unfortunate GNU does not run their own PKI and have their own CA. More risk could be eliminated if we only needed to trust the GNU organization and their root certificate.

## Autotools

Autotools is its own special kind of hell. Autotools is a place where progammers get sent when they have behaved badly.

On new distros you should install Autotools from the distribution. The packages in the Autotools collection which should be installed through the distribution include:

* Aclocal
* Autoconf
* Automake
* Autopoint
* Libtool

The build scripts include `build-autotools.sh` but you should use it sparingly on old distros. Attempting to update Autotools creates a lot of tangential incompatibility problems (which is kind of sad given they have had 25 years or so to get it right).

If you install Autotools using `build-autotools.sh` and it causes more problems then it is worth, then run `clean-autotools.sh`. `clean-autotools.sh` removes all the Autotools artifacts it can find from `/usr/local`. `clean-autotools.sh` does not remove Libtool, so you may need to remove it by hand or reinstall it to ensure it is using the distro's Autotools.

## Self Tests

The scripts attempt to run the program's or library's self tests. Usually the recipe is `make check`, but it is `make test` on occassion.

If the self tests are run and fails, then the script stops before installation. An example for GNU's Gzip is shown below.

```
==========================================
Testsuite summary for gzip 1.8
==========================================
# TOTAL: 18
# PASS:  16
# SKIP:  0
# XFAIL: 0
# FAIL:  2
# XPASS: 0
# ERROR: 0
==========================================
See tests/test-suite.log
Please report to bug-gzip@gnu.org
==========================================
make[4]: *** [test-suite.log] Error 1
make[4]: Leaving directory `/Users/scripts/gzip-1.8/tests'
...
Failed to test Gzip
```

You have three choices on self-test failure. First, you can ignore the failure, `cd` into the program's directory, and then run `sudo make install`.

Second, you can fix the failure, `cd` into the program's directory, run `make`, run `make check`, and then run `sudo make install`.

Third, you can open the `build-prog.sh` script, comment the portion that runs `make check`, and then rerrun the script again. Some libraries, like OpenSSL, use this strategy since the self tests are broken on several platforms.

## Bugs

If you find a bug then submit a patch or raise a bug report.
