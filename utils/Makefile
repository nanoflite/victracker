##########################################################################
#
# FILE  Makefile
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.4 2003/06/24 17:05:55 tlr Exp $
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

all::

# build the distribution archive
DISTDIR:=$(DISTDIR)/utils
dist::	predist #subdirs
	cp Makefile $(DISTDIR)
	cp strip.pl strip_test.asm pitchtab.pl makedisk.pl $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f *~ \#*\#

# eof
