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

ifeq ($(CA65),true)
	FLAG := -C
	EXT := s
else
	FLAG :=
	EXT := asm
endif

PACKAGE_ROOT=..
include	$(PACKAGE_ROOT)/package.mk
include	$(PACKAGE_ROOT)/common.mk

# to avoid problems with old make
SHELL = /bin/sh

################################################
#    DO NOT MODIFY ANYTHING AFTER THIS LINE    #
################################################

all::	djungel-zagor.$(EXT) mystic.$(EXT) blippblopp.$(EXT) slowride.$(EXT) \
	vt-theme.$(EXT)


djungel-zagor.$(EXT):	djungel-zagor.vt
	../vtcomp/vtcomp -L ../vtcomp $(FLAG) $< $@
mystic.$(EXT):	mystic.vt
	../vtcomp/vtcomp -L ../vtcomp $(FLAG) $< $@
blippblopp.$(EXT):	blippblopp.vt
	../vtcomp/vtcomp -L ../vtcomp $(FLAG) $< $@
slowride.$(EXT):	slowride.vt
	../vtcomp/vtcomp -L ../vtcomp $(FLAG) $< $@
vt-theme.$(EXT):	vt-theme.vt
	../vtcomp/vtcomp -L ../vtcomp $(FLAG) $< $@

# build the distribution archive
DISTDIR:=$(DISTDIR)/examples
dist::	predist #subdirs
	cp Makefile $(DISTDIR)
	cp djungel-zagor.vt djungel-zagor.$(EXT) $(DISTDIR)
	cp djungel-zagor_runner.$(EXT) djungel-zagor_runner.prg $(DISTDIR)
	cp mystic.vt mystic.$(EXT) $(DISTDIR)
	cp mystic_runner.$(EXT) mystic_runner.prg $(DISTDIR)
	cp blippblopp.vt blippblopp.$(EXT) $(DISTDIR)
	cp blippblopp_runner.$(EXT) blippblopp_runner.prg $(DISTDIR)
	cp slowride.vt slowride.$(EXT) $(DISTDIR)
	cp slowride_runner.$(EXT) slowride_runner.prg $(DISTDIR)
	cp vt-theme.vt vt-theme.$(EXT) $(DISTDIR)
	cp vt-theme_runner.$(EXT) vt-theme_runner.prg $(DISTDIR)
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
	rm -f *.s *.o *.lbl

# eof
