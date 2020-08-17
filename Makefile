##########################################################################
#
# FILE  Makefile
# Copyright (c) 2000, 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: Makefile,v 1.31 2003/08/26 20:41:24 tlr Exp $
#
# DESCRIPTION
#   Victracker Makefile
#
######

PACKAGE_ROOT=.
include	$(PACKAGE_ROOT)/package.mk
include	$(PACKAGE_ROOT)/common.mk

# to avoid problems with old make
SHELL = /bin/sh

################################################
#    DO NOT MODIFY ANYTHING AFTER THIS LINE    #
################################################

export DISTROOT DISTDIR

all::	subdirs victracker.prg

victracker.prg: sys.asm crunched.prg
	@# determine the length of the data needed to be copied down.
	$(DASM) sys.asm -olencheck.prg -DLENCHECK $(DASMFLAGS)
	@CHECK=lencheck.prg; $(DASMCHECK)
	@# the first half of the program
	dd if=crunched.prg bs=1 count=`wc -c lencheck.prg | sed 's/[\ \t]*\([0-9]\+\).*/\1/g'` > head.prg
	@# skip the load address (= 2 bytes)
	@# and the bytes up to 0x120d (= 12 bytes)
	dd if=head.prg bs=1 skip=14 > head.bin
	@# the second half of the program.
	dd if=crunched.prg bs=1 skip=`wc -c lencheck.prg | sed 's/[\ \t]*\([0-9]\+\).*/\1/g'` > tail.bin
	@# ok, assemble it for real.
	$(DASM) sys.asm -ovictracker.prg $(DASMFLAGS)
	@CHECK=victracker.prg; $(DASMCHECK)

crunched.prg:	linked.prg
	$(PUCRUNCH) -c20 -ffast -x0x1700 $< $@

linked.prg:	main.asm intro.bin musiced.bin
	$(DASM) $< -o$@ $(DASMFLAGS)
	@CHECK=$@; $(DASMCHECK)

intro.bin:	intro.prg
intro.prg:	intro/intro.prg
	cp $< $@
musiced.bin:	musiced.prg
musiced.prg:	musiced/musiced.prg
	cp $< $@

intro/intro.prg:
	cd intro && $(MAKE) all

musiced/musiced.prg:
	cd musiced && $(MAKE) all

# build all distribution stuff.
dist::	dist_tar dist_bin

# build distribution archive
DISTNAME:=$(PACKAGE)-$(VERSION)
DISTROOT:=/tmp/$(DISTNAME)
DISTDIR:=$(DISTROOT)
dist_tar:: predist subdirs victracker.prg
	cp victracker.prg $(DISTDIR)
	cp README.txt LICENSE.txt TODO.txt NEWS.txt $(DISTDIR)
	cp Makefile package.mk common.mk $(DISTDIR)
	cp sys.asm main.asm $(DISTDIR)
	cd /tmp; $(TAR) cf $(DISTNAME).tar $(DISTNAME); \
	$(GZIP) -9 $(DISTNAME).tar
	mv /tmp/$(DISTNAME).tar.gz .
	rm -r $(DISTDIR)

predist::
	rm -rf $(DISTDIR)
	mkdir $(DISTDIR)

# build the binary distribution stuff (d64 and zip).
DISTDIR_BIN:=/tmp/$(DISTNAME)-bin
dist_bin::	predist_bin dist_d64 dist_zip postdist_bin

predist_bin::
	rm -rf $(DISTDIR_BIN)
	mkdir $(DISTDIR_BIN)
	cp victracker.prg $(DISTDIR_BIN)
	cp $(DISTNAME).tar.gz $(DISTDIR_BIN)/vt$(VERSION)-src.tar.gz
	cp examples/djungel-zagor.vt $(DISTDIR_BIN)
	cp examples/djungel-zagor_runner.prg $(DISTDIR_BIN)/djungel-zagor.p.prg
	cp examples/blippblopp.vt $(DISTDIR_BIN)
	cp examples/blippblopp_runner.prg $(DISTDIR_BIN)/blippblopp.p.prg
	cp examples/mystic.vt $(DISTDIR_BIN)
	cp examples/mystic_runner.prg $(DISTDIR_BIN)/mystic.p.prg
	cp examples/slowride.vt $(DISTDIR_BIN)
	cp examples/slowride_runner.prg $(DISTDIR_BIN)/slowride.p.prg
	cp examples/vt-theme.vt $(DISTDIR_BIN)
	cp examples/vt-theme_runner.prg $(DISTDIR_BIN)/vt-theme.p.prg

postdist_bin::
	rm -rf $(DISTDIR_BIN)

# build the d64 archive
dist_d64::
	utils/makedisk.pl -o $(DISTNAME).d64 -N "VICTRACKER $(VERSION),T.L.R"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "----------------,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "VICTRACKER,p" $(DISTDIR_BIN)/victracker.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "VT$(VERSION)-SRC.TAR.GZ,p" $(DISTDIR_BIN)/vt$(VERSION)-src.tar.gz
	utils/makedisk.pl -o $(DISTNAME).d64 -w "----------------,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "DJUNGEL-ZAGOR.VT,p" $(DISTDIR_BIN)/djungel-zagor.vt
	utils/makedisk.pl -o $(DISTNAME).d64 -w "DJUNGEL-ZAGOR.P,p" $(DISTDIR_BIN)/djungel-zagor.p.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "BLIPPBLOPP.VT,p" $(DISTDIR_BIN)/blippblopp.vt
	utils/makedisk.pl -o $(DISTNAME).d64 -w "BLIPPBLOPP.P,p" $(DISTDIR_BIN)/blippblopp.p.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "MYSTIC.VT,p" $(DISTDIR_BIN)/mystic.vt
	utils/makedisk.pl -o $(DISTNAME).d64 -w "MYSTIC.P,p" $(DISTDIR_BIN)/mystic.p.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "SLOWRIDE.VT,p" $(DISTDIR_BIN)/slowride.vt
	utils/makedisk.pl -o $(DISTNAME).d64 -w "SLOWRIDE.P,p" $(DISTDIR_BIN)/slowride.p.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "VT-THEME.VT,p" $(DISTDIR_BIN)/vt-theme.vt
	utils/makedisk.pl -o $(DISTNAME).d64 -w "VT-THEME.P,p" $(DISTDIR_BIN)/vt-theme.p.prg
	utils/makedisk.pl -o $(DISTNAME).d64 -w "----------------,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w " VICTRACKER $(VERSION) ,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "    BY T.L.R    ,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "   $(RELDATE)   ,d"
ifdef BETA
	utils/makedisk.pl -o $(DISTNAME).d64 -w "NOTE:           ,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "INCOMPLETE BETA-,d"
	utils/makedisk.pl -o $(DISTNAME).d64 -w "TEST RELEASE.   ,d"
endif
	utils/makedisk.pl -o $(DISTNAME).d64 -w "----------------,d"

# build the zip archive
dist_zip::
	cd $(DISTDIR_BIN); zip -m -r $(DISTNAME)-vic20.zip .
	mv $(DISTDIR_BIN)/$(DISTNAME)-vic20.zip .

# clean out old targets
clean::	subdirs
	rm -f *~ \#*\#
	rm -f a.out
	rm -f victracker.prg
	rm -f crunched.prg linked.prg
	rm -f intro.prg musiced.prg intro.bin musiced.bin
	rm -f head.prg head.bin tail.bin lencheck.prg

# these are our subdirectories, they must be provided as dependencies
# for everything that should propagate.
subdirs::
	cd utils && $(MAKE) $(MAKECMDGOALS)
	cd vtcomp && $(MAKE) $(MAKECMDGOALS)
	cd examples && $(MAKE) $(MAKECMDGOALS)
	cd doc && $(MAKE) $(MAKECMDGOALS)
	cd include && $(MAKE) $(MAKECMDGOALS)
	cd intro && $(MAKE) $(MAKECMDGOALS)
	cd musiced && $(MAKE) $(MAKECMDGOALS)

# eof
