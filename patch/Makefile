# ------------------------------------------------------------------
# This file is part of bzip2/libbzip2, a program and library for
# lossless, block-sorting data compression.
#
# bzip2/libbzip2 version 1.0.8 of 13 July 2019
# Copyright (C) 1996-2019 Julian Seward <jseward@acm.org>
#
# Please read the WARNING, DISCLAIMER and PATENTS sections in the
# README file.
#
# This program is released under the terms of the license contained
# in the file LICENSE.
# ------------------------------------------------------------------

SHELL=/bin/sh

# https://www.gnu.org/prep/standards/html_node/Makefile-Basics.html
.SUFFIXES:
.SUFFIXES: .c .o

# Where you want it installed when you do 'make install'
# https://www.gnu.org/prep/standards/html_node/Directory-Variables.html
PREFIX=/usr/local
LIBDIR=$(PREFIX)/lib
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/man
INCLUDEDIR=$(PREFIX)/include

# To assist in cross-compiling
CC=
CPPFLAGS=
CFLAGS=-Wall -Winline -O2 -g
AR=ar
ARFLAGS=cq
RANLIB=ranlib
LDFLAGS=

# https://www.gnu.org/prep/standards/html_node/Command-Variables.html
# BZIP_CFLAGS follows ALL_CFLAGS in the example.
BZIP_CFLAGS=-D_FILE_OFFSET_BITS=64 $(CFLAGS)

OBJS= blocksort.o  \
      huffman.o    \
      crctable.o   \
      randtable.o  \
      compress.o   \
      decompress.o \
      bzlib.o

all: libbz2.a bzip2 bzip2recover test

bzip2: bzip2.o libbz2.a
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) $(LDFLAGS) $< -o $@ ./libbz2.a

bzip2recover: bzip2recover.o
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) $(LDFLAGS) $< -o $@

libbz2.a: $(OBJS)
	rm -f $@
	$(AR) $(ARFLAGS) $@ $(OBJS)
	@if ( test -f $(RANLIB) -o -f /usr/bin/ranlib -o \
		-f /bin/ranlib -o -f /usr/ccs/bin/ranlib ) ; then \
		echo $(RANLIB) $@ ; \
		$(RANLIB) $@ ; \
	fi

check: test
test: bzip2
	@cat words1
	./bzip2 -1  < sample1.ref > sample1.rb2
	./bzip2 -2  < sample2.ref > sample2.rb2
	./bzip2 -3  < sample3.ref > sample3.rb2
	./bzip2 -d  < sample1.bz2 > sample1.tst
	./bzip2 -d  < sample2.bz2 > sample2.tst
	./bzip2 -ds < sample3.bz2 > sample3.tst
	cmp sample1.bz2 sample1.rb2
	cmp sample2.bz2 sample2.rb2
	cmp sample3.bz2 sample3.rb2
	cmp sample1.tst sample1.ref
	cmp sample2.tst sample2.ref
	cmp sample3.tst sample3.ref
	@cat words3

install: installdirs bzip2 bzip2recover
	cp -f bzip2 $(BINDIR)/bzip2
	cp -f bzip2 $(BINDIR)/bunzip2
	cp -f bzip2 $(BINDIR)/bzcat
	cp -f bzip2recover $(BINDIR)/bzip2recover
	chmod a+x $(BINDIR)/bzip2
	chmod a+x $(BINDIR)/bunzip2
	chmod a+x $(BINDIR)/bzcat
	chmod a+x $(BINDIR)/bzip2recover
	cp -f bzip2.1 $(MANDIR)/man1
	chmod a+r $(MANDIR)/man1/bzip2.1
	cp -f bzlib.h $(INCLUDEDIR)
	chmod a+r $(INCLUDEDIR)/bzlib.h
	cp -f libbz2.a $(LIBDIR)
	chmod a+r $(LIBDIR)/libbz2.a
	cp -f bzgrep $(BINDIR)/bzgrep
	ln -s -f $(BINDIR)/bzgrep $(BINDIR)/bzegrep
	ln -s -f $(BINDIR)/bzgrep $(BINDIR)/bzfgrep
	chmod a+x $(BINDIR)/bzgrep
	cp -f bzmore $(BINDIR)/bzmore
	ln -s -f $(BINDIR)/bzmore $(BINDIR)/bzless
	chmod a+x $(BINDIR)/bzmore
	cp -f bzdiff $(BINDIR)/bzdiff
	ln -s -f $(BINDIR)/bzdiff $(BINDIR)/bzcmp
	chmod a+x $(BINDIR)/bzdiff
	cp -f bzgrep.1 bzmore.1 bzdiff.1 $(MANDIR)/man1
	chmod a+r $(MANDIR)/man1/bzgrep.1
	chmod a+r $(MANDIR)/man1/bzmore.1
	chmod a+r $(MANDIR)/man1/bzdiff.1
	echo ".so man1/bzgrep.1" > $(MANDIR)/man1/bzegrep.1
	echo ".so man1/bzgrep.1" > $(MANDIR)/man1/bzfgrep.1
	echo ".so man1/bzmore.1" > $(MANDIR)/man1/bzless.1
	echo ".so man1/bzdiff.1" > $(MANDIR)/man1/bzcmp.1

installdirs:
	if ( test ! -d $(BINDIR) ) ; then mkdir -p $(BINDIR) ; fi
	if ( test ! -d $(LIBDIR) ) ; then mkdir -p $(LIBDIR) ; fi
	if ( test ! -d $(LIBDIR)/pkgconfig ) ; then mkdir -p $(LIBDIR)/pkgconfig ; fi
	if ( test ! -d $(MANDIR) ) ; then mkdir -p $(MANDIR) ; fi
	if ( test ! -d $(MANDIR)/man1 ) ; then mkdir -p $(MANDIR)/man1 ; fi
	if ( test ! -d $(INCLUDEDIR) ) ; then mkdir -p $(INCLUDEDIR) ; fi

clean:
	rm -f *.o libbz2.a bzip2 bzip2recover \
	sample1.rb2 sample2.rb2 sample3.rb2 \
	sample1.tst sample2.tst sample3.tst

# https://www.gnu.org/prep/standards/html_node/Makefile-Basics.html
blocksort.o: blocksort.c
	@cat words0
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
huffman.o: huffman.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
crctable.o: crctable.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
randtable.o: randtable.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
compress.o: compress.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
decompress.o: decompress.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
bzlib.o: bzlib.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
bzip2.o: bzip2.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@
bzip2recover.o: bzip2recover.c
	$(CC) $(CPPFLAGS) $(BZIP_CFLAGS) -c $< -o $@


distclean: clean
	rm -f manual.ps manual.html manual.pdf bzip2.txt bzip2.1.preformatted

DISTNAME=bzip2-1.0.8
dist: check manual
	rm -f $(DISTNAME)
	ln -s -f . $(DISTNAME)
	tar cvf $(DISTNAME).tar \
	   $(DISTNAME)/blocksort.c \
	   $(DISTNAME)/huffman.c \
	   $(DISTNAME)/crctable.c \
	   $(DISTNAME)/randtable.c \
	   $(DISTNAME)/compress.c \
	   $(DISTNAME)/decompress.c \
	   $(DISTNAME)/bzlib.c \
	   $(DISTNAME)/bzip2.c \
	   $(DISTNAME)/bzip2recover.c \
	   $(DISTNAME)/bzlib.h \
	   $(DISTNAME)/bzlib_private.h \
	   $(DISTNAME)/Makefile \
	   $(DISTNAME)/LICENSE \
	   $(DISTNAME)/bzip2.1 \
	   $(DISTNAME)/bzip2.1.preformatted \
	   $(DISTNAME)/bzip2.txt \
	   $(DISTNAME)/words0 \
	   $(DISTNAME)/words1 \
	   $(DISTNAME)/words2 \
	   $(DISTNAME)/words3 \
	   $(DISTNAME)/sample1.ref \
	   $(DISTNAME)/sample2.ref \
	   $(DISTNAME)/sample3.ref \
	   $(DISTNAME)/sample1.bz2 \
	   $(DISTNAME)/sample2.bz2 \
	   $(DISTNAME)/sample3.bz2 \
	   $(DISTNAME)/dlltest.c \
	   $(DISTNAME)/manual.html \
	   $(DISTNAME)/manual.pdf \
	   $(DISTNAME)/manual.ps \
	   $(DISTNAME)/README \
	   $(DISTNAME)/README.COMPILATION.PROBLEMS \
	   $(DISTNAME)/README.XML.STUFF \
	   $(DISTNAME)/CHANGES \
	   $(DISTNAME)/libbz2.def \
	   $(DISTNAME)/libbz2.dsp \
	   $(DISTNAME)/dlltest.dsp \
	   $(DISTNAME)/makefile.msc \
	   $(DISTNAME)/unzcrash.c \
	   $(DISTNAME)/spewG.c \
	   $(DISTNAME)/mk251.c \
	   $(DISTNAME)/bzdiff \
	   $(DISTNAME)/bzdiff.1 \
	   $(DISTNAME)/bzmore \
	   $(DISTNAME)/bzmore.1 \
	   $(DISTNAME)/bzgrep \
	   $(DISTNAME)/bzgrep.1 \
	   $(DISTNAME)/Makefile-libbz2_so \
	   $(DISTNAME)/bz-common.xsl \
	   $(DISTNAME)/bz-fo.xsl \
	   $(DISTNAME)/bz-html.xsl \
	   $(DISTNAME)/bzip.css \
	   $(DISTNAME)/entities.xml \
	   $(DISTNAME)/manual.xml \
	   $(DISTNAME)/format.pl \
	   $(DISTNAME)/xmlproc.sh
	gzip -v $(DISTNAME).tar

# For rebuilding the manual from sources on my SuSE 9.1 box

MANUAL_SRCS= 	bz-common.xsl bz-fo.xsl bz-html.xsl bzip.css \
		entities.xml manual.xml

bzip2.txt: bzip2.1
	MANWIDTH=67 man --ascii ./$^ > $@

bzip2.1.preformatted: bzip2.1
	MAN_KEEP_FORMATTING=1 MANWIDTH=67 man -E UTF-8 ./$^ > $@

manual: manual.html manual.ps manual.pdf bzip2.txt bzip2.1.preformatted

manual.ps: $(MANUAL_SRCS)
	./xmlproc.sh -ps manual.xml

manual.pdf: $(MANUAL_SRCS)
	./xmlproc.sh -pdf manual.xml

manual.html: $(MANUAL_SRCS)
	./xmlproc.sh -html manual.xml
