##########################################################################
#
# FILE  Makefile
# Copyright (c) 2000, 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.10 2003/08/26 10:34:02 tlr Exp $
#
# DESCRIPTION
#   Victracker vtcomp Makefile
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

all::	vtcomp player.asm

vtcomp:	vtcomp.o util.o

vtcomp.o:	vtcomp.c tune.h util.h vtcomp.h
util.o:		util.c util.h vtcomp.h

player.asm:	../musiced/player.asm
	../utils/strip.pl -D PL_PACKED -o $@ $<

# build the distribution archive
DISTDIR:=$(DISTDIR)/vtcomp
dist::	predist player.asm #subdirs
	cp Makefile $(DISTDIR)
	cp vtcomp.c vtcomp.h tune.h $(DISTDIR)
	cp util.c util.h $(DISTDIR)
	cp runner.asm player.asm $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f *.o
	rm -f *~ \#*\#
	rm -f vtcomp
	rm -f a.out

# eof
