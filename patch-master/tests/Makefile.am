# Copyright (C) 1989-1993, 1997-1999, 2002-2003, 2006, 2009-2012 Free Software
# Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Process this file with automake to produce Makefile.in.

TESTS = \
	asymmetric-hunks \
	backup-prefix-suffix \
	bad-filenames \
	bad-usage \
	concat-git-diff \
	context-format \
	copy-rename \
	corrupt-patch \
	corrupt-reject-files \
	create-delete \
	create-directory \
	criss-cross \
	crlf-handling \
	dash-o-append \
	deep-directories \
	ed-style \
	empty-files \
	false-match \
	fifo \
	file-create-modes \
	file-modes \
	filename-choice \
	git-binary-diff \
	git-cleanup \
	garbage \
	global-reject-files \
	inname \
	line-numbers \
	merge \
	mangled-numbers-abort \
	mixed-patch-types \
	munged-context-format \
	need-filename \
	no-mode-change-git-diff \
	no-newline-triggers-assert \
	preserve-c-function-names \
	preserve-mode-and-timestamp \
	quoted-filenames \
	read-only-files \
	reject-format \
	remember-backup-files \
	remember-reject-files \
	remove-directories \
	symlinks \
	unmodified-files

XFAIL_TESTS = \
	dash-o-append \
	context-format

EXTRA_DIST = \
	$(TESTS) \
	test-lib.sh

TESTS_ENVIRONMENT = \
	abs_top_builddir=$(abs_top_builddir); \
	export abs_top_builddir;

LOG_COMPILER = \
	$(SHELL)
