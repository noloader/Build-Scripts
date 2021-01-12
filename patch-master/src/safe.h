/* safe path traversal functions for 'patch' */

/* Copyright (C) 2015 Free Software Foundation, Inc.

   Written by Tim Waugh <twaugh@redhat.com> and
   Andreas Gruenbacher <agruenba@redhat.com>.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <stdbool.h>

extern bool unsafe;

int safe_stat (const char *pathname, struct stat *buf);
int safe_lstat (const char *pathname, struct stat *buf);
int safe_open (const char *pathname, int flags, mode_t mode);
int safe_rename (const char *oldpath, const char *newpath);
int safe_mkdir (const char *pathname, mode_t mode);
int safe_rmdir (const char *pathname);
int safe_unlink (const char *pathname);
int safe_symlink (const char *target, const char *linkpath);
int safe_chmod (const char *pathname, mode_t mode);
int safe_lchown (const char *pathname, uid_t owner, gid_t group);
int safe_lutimens (const char *pathname, struct timespec const times[2]);
ssize_t safe_readlink(const char *pathname, char *buf, size_t bufsiz);
int safe_access(const char *pathname, int mode);
