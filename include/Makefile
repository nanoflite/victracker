##########################################################################
#
# FILE  Makefile
# Copyright (c) 2000, 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.3 2003/07/30 15:27:47 tlr Exp $
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
DISTDIR:=$(DISTDIR)/include
dist::	predist #subdirs
	cp Makefile $(DISTDIR)
	cp macros.i vic20.i $(DISTDIR)
predist::
	mkdir $(DISTDIR)

# clean out old targets
clean::	#subdirs
	rm -f *~ \#*\#

# eof
