##########################################################################
#
# FILE  Makefile
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.8 2003/11/03 19:41:02 tlr Exp $
#
# DESCRIPTION
#   Victracker Makefile
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

all::	djungel-zagor.asm mystic.asm blippblopp.asm slowride.asm \
	vt-theme.asm


djungel-zagor.asm:	djungel-zagor.vt
	../vtcomp/vtcomp -L ../vtcomp $< $@
mystic.asm:	mystic.vt
	../vtcomp/vtcomp -L ../vtcomp $< $@
blippblopp.asm:	blippblopp.vt
	../vtcomp/vtcomp -L ../vtcomp $< $@
slowride.asm:	slowride.vt
	../vtcomp/vtcomp -L ../vtcomp $< $@
vt-theme.asm:	vt-theme.vt
	../vtcomp/vtcomp -L ../vtcomp $< $@

# build the distribution archive
DISTDIR:=$(DISTDIR)/examples
dist::	predist #subdirs
	cp Makefile $(DISTDIR)
	cp djungel-zagor.vt djungel-zagor.asm $(DISTDIR)
	cp djungel-zagor_runner.asm djungel-zagor_runner.prg $(DISTDIR)
	cp mystic.vt mystic.asm $(DISTDIR)
	cp mystic_runner.asm mystic_runner.prg $(DISTDIR)
	cp blippblopp.vt blippblopp.asm $(DISTDIR)
	cp blippblopp_runner.asm blippblopp_runner.prg $(DISTDIR)
	cp slowride.vt slowride.asm $(DISTDIR)
	cp slowride_runner.asm slowride_runner.prg $(DISTDIR)
	cp vt-theme.vt vt-theme.asm $(DISTDIR)
	cp vt-theme_runner.asm vt-theme_runner.prg $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f djungel-zagor*.asm djungel-zagor*.prg
	rm -f mystic*.asm mystic*.prg
	rm -f blippblopp*.asm blippblopp*.prg
	rm -f slowride*.asm slowride*.prg
	rm -f vt-theme*.asm vt-theme*.prg
	rm -f *~ \#*\#

# eof
