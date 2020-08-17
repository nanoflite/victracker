##########################################################################
#
# FILE  Makefile
# Copyright (c) 2000, 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.10 2003/08/26 10:29:58 tlr Exp $
#
# DESCRIPTION
#   Victracker intro Makefile
#
######

PACKAGE_ROOT=..
include	$(PACKAGE_ROOT)/package.mk
include	$(PACKAGE_ROOT)/common.mk

# to avoid problems with old make
SHELL = /bin/sh

################################################
#    DO NOT MODIFY ANYTHING AFTER THIS LINE    #
################################################

all::	intro.prg

intro.prg:	intro.asm logo18x9bg.bin font.bin
	$(DASM) $< -o$@ $(DASMFLAGS)
	@CHECK=$@; $(DASMCHECK)

logo18x9bg.bin:	logo18x9bg.prg
	@# len=0x600  (strip of the last 0x200)
	dd if=$< bs=1 skip=2 count=1536 > $@

font.bin:	font.prg

# build the distribution archive
DISTDIR:=$(DISTDIR)/intro
dist::	predist #subdirs
	cp Makefile intro.asm font.prg logo18x9bg.prg $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f *.o
	rm -f *~ \#*\#
	rm -f intro.prg logo18x9bg.bin font.bin
	rm -f a.out

# eof
