##########################################################################
#
# FILE  Makefile
# Copyright (c) 2000, 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.15 2003/08/26 10:29:58 tlr Exp $
#
# DESCRIPTION
#   Victracker musiced Makefile
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

all::	musiced.prg

musiced.prg:	musiced.asm screen.asm keys.asm disk.asm docs.asm \
                editor.asm editpattlist.asm editpattern.asm \
		editarp.asm editsound.asm \
		playersupport.asm player.asm playerdata.asm vt.i
	$(DASM) $< -o$@ $(DASMFLAGS)
	@CHECK=$@; $(DASMCHECK)

# build the distribution archive
DISTDIR:=$(DISTDIR)/musiced
dist::	predist #subdirs
	cp Makefile $(DISTDIR)
	cp musiced.asm screen.asm keys.asm disk.asm docs.asm $(DISTDIR)
	cp editor.asm editpattlist.asm editpattern.asm $(DISTDIR)
	cp editarp.asm editsound.asm $(DISTDIR)
	cp playersupport.asm player.asm playerdata.asm $(DISTDIR)
	cp vt.i $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f *.o
	rm -f *~ \#*\#
	rm -f musiced.prg
	rm -f a.out

# eof
