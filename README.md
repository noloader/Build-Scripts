# Build-Scripts
This GitHub is a collection of build scripts useful when testing on downlevel and unique clients. It should result in working SSH, Wget, cURL and Git clients on systems like Fedora 10, CentOS 5 and Solaris 11.

Wget should be built first when working on older systems. CentOS 5 provides Wget 1.11, and it does not support SNI. The old Wget will fail to download cURL which breaks the Git build. cURL fails due to shared hosting and lack of SNI.

The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver an authentic tarball. That's the purpose of build-cacerts.sh and build-wget.sh - Wget and the correct CA are enough to bootstrap the process with minimal risk.
