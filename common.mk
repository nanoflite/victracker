##########################################################################
#
# FILE  common.mk
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: common.mk,v 1.8 2003/08/26 10:38:45 tlr Exp $
#
# DESCRIPTION
#   common Makefile definitions.
#
######

# programs
TAR=tar
GZIP=gzip
CC=gcc
DASM=dasm
PUCRUNCH=pucrunch

# macro to check if DASM produced an empty output file.
# usage
#   $(DASM) $< -o$@ $(DASMFLAGS)
#   @CHECK=$@; $(DASMCHECK)
#
define DASMCHECK
if [ ! -s "$${CHECK}" ]; then rm $${CHECK}; echo "ERROR: dasm produced an empty output file, aborting!"; exit -1; else echo "dasm output file ok."; fi
endef

# determine version variables
VERSION_MAJOR=$(shell echo $(VERSION) | sed "s/\.[0-9]\+//")
VERSION_MINOR=$(shell echo $(VERSION) | sed "s/[0-9]\+\.//")

# determine year variable
RELYEAR=$(shell echo $(RELDATE) | sed "s/-[0-9]\+-[0-9]\+//")

# flags for programs
CFLAGS = -Wall -DPACKAGE=\"$(PACKAGE)\" -DVERSION=\"$(VERSION)\" -DVERSION_MAJOR=$(VERSION_MAJOR) -DVERSION_MINOR=$(VERSION_MINOR)
# DASMFLAGS=-DPACKAGE=\"$(PACKAGE)\" -DVERSION=\"$(VERSION)\" -DRELDATE=\"$(RELDATE)\" -DRELYEAR=$(RELYEAR) -DVERSION_MAJOR=$(VERSION_MAJOR) -DVERSION_MINOR=$(VERSION_MINOR) 

# rules for common
.SUFFIXES: .prg .bin .asm
# build .bin from .prg by stripping the first 2 bytes (loadaddr)
%.bin: %.prg
	dd if=$< bs=1 skip=2 > $@

# eof
