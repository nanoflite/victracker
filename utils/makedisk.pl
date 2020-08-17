#! /usr/bin/perl -w
##########################################################################
#
# FILE  makedisk.pl
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: makedisk.pl,v 1.6 2003/07/08 20:56:53 tlr Exp $
#
# DESCRIPTION
#   Write to a 1541 (.d64) disk image.
#   NOTE: error checking is not to good, and it is somewhat slow.
#
# REFERENCES
#   "Inside Commodore DOS", Richard Immers and Gerald G. Neufeld,
#         Second Printing 1985, ISBN 0-88190-366-3, Datamost, Inc.
#   "Das grosse FloppyBuch", Englisch & Szczepanowski, 1984, 
#         ISBN 3-89011-005-3, Data Becker,GmbH 
#
######
use strict;
use Getopt::Std;

my $PROGRAM="makedisk.pl";
my $PROGRAM_VERSION="0.0.1";

# globals
my $debug_g;
my $verbose_g;
my $oldstyle_g;
my @sectors_g=(0,
    21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21, # tracks 1-17
    19,19,19,19,19,19,19,                               # tracks 18-24
    18,18,18,18,18,18,                                  # tracks 25-30
    17,17,17,17,17                                      # tracks 31-35
);
my @interleave_g=(0,
    10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10, # tracks 1-17
    3,10,10,10,10,10,10,                                # tracks 18-24
    10,10,10,10,10,10,                                  # tracks 25-30
    10,10,10,10,10                                      # tracks 31-35
);

##########################################################################
#
# the MAIN code
#
# checks command line arguments
# prints help if appropriate, calls process_file() for
# all specified files.
#
######
my %opts;
my $imagefile="out.d64";
my $file;
my $writename;
my $formatname;

getopts ('o:w:N:OvdVh',\%opts);

$verbose_g=$opts{v};
$debug_g=$opts{d};

# print version and exit if -V
if ($opts{V}) {
    print $PROGRAM," ",$PROGRAM_VERSION,"\n";
    exit 0;
}

# print help and exit if -h
if ($opts{h}) {
    print <<EOF;
$PROGRAM $PROGRAM_VERSION - write to a 1541 (.d64) disk image.
Copyright (c) 2003 Daniel Kahlin <daniel\@kahlin.net>

USAGE: $PROGRAM [-h][-V][-v][-d][-o<image>][-N<name>,<id>][-w<name>,[<type>]][-O][<file>]
  -w <name>,[<type>] write file to image.
  -N <format>,<id> format image.
  -o <image> image name.
  -O old style format.
  -h display this help text
  -V display version
  -v be verbose
  -d dump lots of (weird) debugging info
EOF
    exit 0;
}

$oldstyle_g=$opts{O};

if ($opts{o}) {
    $imagefile=$opts{o};
}
if ($opts{w}) {
    $writename=$opts{w};
}
if ($opts{N}) {
    $formatname=$opts{N};
}
($writename && $formatname) && die "You may only select one of '-w' and '-N'";
($writename || $formatname) || die "You must select one of '-w' and '-N'";

($file=shift @ARGV);

#
# Information gathered, act on it!
#
if ($formatname) {
    my ($name,$id)=split ",",$formatname;
    my $convname=substr(uc($name),0,16);
    $convname .= "\xa0" x (16-length($convname));
    my $convid=substr(uc($id),0,5);
    $convid .= "\xa0" x (5-length($convid));
    if (length($id)<=2) {
	(substr $convid,3)="2A";
    }
    ($debug_g) && print "\"",$convname,"\" \"",$convid,"\"\n";

    open(IMAGE, "+> $imagefile") || die $PROGRAM, ": could not open image file\n";
    binmode IMAGE;

    d64_format(*IMAGE,$convname,$convid);

    close IMAGE;
}

if ($writename) {
    my ($name,$type)=split ",",$writename;
    (!$type) && ($type="p", 1);
    my $convname=substr(uc($name),0,16);
    $convname .= "\xa0" x (16-length($convname));
    ($debug_g) && print "\"",$convname,"\" ",$type,"\n";

    open(IMAGE, "+< $imagefile") || die $PROGRAM, ": could not open image file\n";
    binmode IMAGE;

    my ($trk,$sec,$blks);
    if ($file) {
	open(INFILE, "< $file") || die $PROGRAM, ": could not open input file\n";
	binmode INFILE;
	($trk,$sec,$blks)=d64_writefile(*IMAGE,*INFILE,10);
	close INFILE;
	d64_addfile(*IMAGE,$convname,0xc2,$trk,$sec,$blks);
    } else {
	d64_addfile(*IMAGE,$convname,0xc0,1,0,0);
    }
    close IMAGE;
}

##########################################################################
#
# NAME  d64_writefile ()
#
# SYNOPSIS  ($trk,$sec,$blks) = d64_writefile ($imagefile,$infile,$interleave)
#  
# DESCRIPTION
#   write a file to the disk.  Return the size in blocks and the starting
#   track and sector.
#
# KNOWN BUGS
#   will fail on "disk full", and if the file is an even multiple of
#   254 bytes.
#
#   file block:
#     0x00      track of the next file block.
#     0x01      sector of the next file block.
#     0x02-0xff 254 bytes of data.

#   last file block:
#     0x00      Null to indicate that this is the last block
#     0x01      Position of the last byte in this block. (N) 
#     0x02-N    N-2 bytes of data.
#     N+1-0xff  <don't care>
#
######
sub d64_writefile
{
# parameters
    my ($imagefile,$infile,$interleave) = @_;
# locals
    my ($bam,$firsttrk,$firstsec,$newtrk,$newsec,$trk,$sec,$data,$blks,$nread,$sector);

    $blks=0;
    $bam=d64_read($imagefile,18,0);
    ($firsttrk,$firstsec)=d64_findfreefile(\$bam,19,0,10);
    ($trk,$sec)=($firsttrk,$firstsec);

    do {
	$nread = read $infile, $data, 254;
	if ($nread == 254) {
	    ($newtrk,$newsec)=d64_findfreefile(\$bam,19,0,10);
# Create an empty sector
	    $sector=pack "H512", "00" x 256;
	    (substr $sector,0x00,2)=pack "CC", $newtrk,$newsec;
	    (substr $sector,0x02,254)=$data;
	    
	} else {
# Create an empty sector
	    $sector=pack "H512", "00" x 256;
	    (substr $sector,0x00,2)=pack "CC", 0,($nread+2)-1;
	    (substr $sector,0x02,length($data))=$data;
	}
	d64_write($imagefile,$trk,$sec,$sector);
	$blks++;
	($trk,$sec)=($newtrk,$newsec);
    } while ($nread == 254);

    d64_write($imagefile,18,0,$bam);

    return ($firsttrk,$firstsec,$blks);
}

##########################################################################
#
# NAME  d64_addfile ()
#
# SYNOPSIS  $ret = d64_addfile ($imagefile,$name,$type,$trk,$sec,$blks)
#  
# DESCRIPTION
#   add an entry to the directory.
#
#   directory block:
#     0x00-0x01 track and sector of the next directory block.
#               (0x00,0xff if the last)
#     0x02      entry #0
#     0x22      entry #1
#     0x42      entry #2
#     0x62      entry #3
#     0x82      entry #4
#     0xa2      entry #5
#     0xc2      entry #6
#     0xe2      entry #7
#
#   each entry:
#     0x00      file type
#     0x01-0x02 track and sector of data
#     0x03-0x12 filename padded with 0xa0
#     0x13-0x15 used for REL files only (otherwise zero)
#     0x16-0x19 unused (normally zero)
#     0x1a-0x1b track and sector during '@' replacement
#     0x1c-0x1d file length in blocks (low,high)
#
######
sub d64_addfile
{
# parameters
    my ($imagefile,$name,$type,$trk,$sec,$blks) = @_;
# locals
    my ($bam,$dir,$dirtrk,$dirsec,$entrynum,$entrytrk,$entrysec,$nexttrk,$nextsec,$len);

    $bam=d64_read($imagefile,18,0);
    ($dirtrk,$dirsec) = unpack "CC", (substr $bam,0x00,2);   # link to the next sector

    # find first empty entry
    do {
	$dir=d64_read($imagefile,$dirtrk,$dirsec);
	($nexttrk,$nextsec) = unpack "CC", (substr $dir,0x00,2);   # link to the next sector
	for (my $i=0; $i<8 && not defined $entrynum; $i++) {
	    my $offs=0x02 + $i * 0x20;
	    ($debug_g) && print "scanning entry $i ($offs)\n";
	    my $etype = unpack "C", (substr $dir,$offs,1);
	    if ($etype==0x00 && not defined $entrynum) {
		$entrynum=$i;
		$entrytrk=$dirtrk;
		$entrysec=$dirsec;
	    }
	}
	if ($nexttrk==0x00 && $nextsec==0xff && not defined $entrynum) {
	    ($nexttrk,$nextsec)=d64_findfree(\$bam,$dirtrk,$dirsec,3);
	    (substr $dir,0x00,2)=pack "CC", $nexttrk,$nextsec;          # link to the next sector
	    d64_write($imagefile,$dirtrk,$dirsec,$dir);
# Create an empty directory 
	    my $dir=pack "H512", "00" x 256;
	    (substr $dir,0x00,2)=pack "CC", 0,0xff;          # link to the next sector
	    d64_write($imagefile,$nexttrk,$nextsec,$dir);

	}
	$dirtrk=$nexttrk;
	$dirsec=$nextsec;
    } while (not defined $entrynum);

    my $offs=0x02+$entrynum*0x20;
    ($debug_g) && print "found entry $entrynum ($offs)\n";
    (substr $dir,$offs,0x1e) = pack "CCCa16CCCCCCCCCv", $type,$trk,$sec,$name,0,0,0,0,0,0,0,0,0,$blks;
    d64_write($imagefile,$entrytrk,$entrysec,$dir);
    d64_write($imagefile,18,0,$bam);

}

##########################################################################
#
# NAME  d64_format ()
#
# SYNOPSIS  d64_format ($imagefile,$name,$id)
#  
# DESCRIPTION
#   Read data from a sector.
#
######
sub d64_format
{
# parameters
    my ($imagefile,$convname,$convid) = @_;
# locals
    my ($trk,$sec);

# create an empty image
    for ($trk=1; $trk<=35; $trk++) {
	for ($sec=0; $sec<$sectors_g[$trk]; $sec++) {
	    my $sector;

	    if ($oldstyle_g) {
		$sector = pack "H512", "00" . "01" x 255;
	    } else {
		$sector = pack "H512", "00" x 256;
	    }
	    d64_write($imagefile,$trk,$sec,$sector);
	}
    }

# Create a BAM (18,0)
    my $bam=pack "H512", "00" x 256;
    (substr $bam,0x00,2)=pack "CC", 18,1;            # link to the next sector
    (substr $bam,0x02,2)=pack "CC", 0x41,0x00;       # format identifier
    (substr $bam,0x90,0x1b)=pack "H54", "a0" x 0x1b; # padding 
    (substr $bam,0x90,16)=$convname;                 # the disk name string
    (substr $bam,0xa2,5)=$convid;                    # disk id string

# free all sectors
    for ($trk=1; $trk<=35; $trk++) {
	(substr $bam,(0x04+($trk-1)*4),4)=pack "Cb24", $sectors_g[$trk], "1" x $sectors_g[$trk] . "0" x (24-$sectors_g[$trk]);
    }

# allocate 18,0 and 18,1
    bam_allocate(\$bam,18,0);
    bam_allocate(\$bam,18,1);
    d64_write($imagefile,18,0,$bam);

# Create an empty directory (18,1)
    my $dir=pack "H512", "00" x 256;
    (substr $dir,0x00,2)=pack "CC", 0,0xff;          # link to the next sector
    d64_write($imagefile,18,1,$dir);

}

##########################################################################
#
# NAME  d64_findfreefile ()
#
# SYNOPSIS  ($trk,$sec) = d64_findfreefile ($bam_ref,$trk,$sec,$interleave)
#  
# DESCRIPTION
#
######
sub d64_findfreefile
{
# parameters
    my ($bam_ref,$trk,$sec,$interleave) = @_;
# locals
    my ($newtrk,$newsec,$ret,$done);
    
    $ret=1;
    $done=0;
    while (!$done) {
	($newtrk,$newsec)=d64_findfree($bam_ref,$trk,$sec,$interleave);
	if ($newtrk==0) {
	    $sec=0;
	    if ($trk>18) {
		$trk++;
		if ($trk>35) {
		    $trk=17;
		}
	    } elsif ($trk<18) {
		$trk--;
		if ($trk<0) {
		    $ret=0;
		    $done=1;
		}
	    }
	} else {
	    $trk=$newtrk;
	    $sec=$newsec;
	    $done=1;
	}
    } 

    if ($ret) {
	($debug_g) && print "found new sector $trk,$sec\n";
	return ($trk,$sec);
    } else {
	return (0,0);
    }
}

##########################################################################
#
# NAME  d64_findfree ()
#
# SYNOPSIS  ($trk,$sec) = d64_findfree ($bam_ref,$trk,$sec,$interleave)
#  
# DESCRIPTION
#
######
sub d64_findfree
{
# parameters
    my ($bam_ref,$trk,$sec,$interleave) = @_;
# locals
    my ($count,$ret);

    $count=0;
    while (!($ret=bam_allocate($bam_ref,$trk,$sec)) && $count<$sectors_g[$trk]) {
	$sec=($sec+$interleave) % $sectors_g[$trk];
	$count++;
    } 

    if ($ret) {
	($debug_g) && print "found new sector $trk,$sec\n";
	return ($trk,$sec);
    } else {
	return (0,0);
    }
}

##########################################################################
#
# NAME  bam_allocate ()
#
# SYNOPSIS  $ret = bam_allocate ($bam_ref,$trk,$sec)
#  
# DESCRIPTION
#   Allocate a block in the bam.  (returns 0 if failure)
#
######
sub bam_allocate
{
# parameters
    my ($bam_ref,$trk,$sec) = @_;
# locals
    my ($freenum,$freemask);

# get current allocation for this track
    ($freenum,$freemask) = unpack  "Cb24", (substr $$bam_ref,(0x04+($trk-1)*4),4);

    if ((substr $freemask,$sec,1)=="0") {
	return 0;
    }
    (substr $freemask,$sec,1) = "0";
    $freenum--;

# write new allocation for this track
    (substr $$bam_ref,(0x04+($trk-1)*4),4)=pack "Cb24", $freenum, $freemask;
    
    ($debug_g) && print "allocated $trk,$sec\n";
    ($debug_g) && print "  $freenum $freemask\n";

# ok, return;
    return 1;
}

##########################################################################
#
# NAME  bam_free ()
#
# SYNOPSIS  $ret = bam_free ($bam_ref,$trk,$sec)
#  
# DESCRIPTION
#   Free a block in the bam.  (returns 0 if failure)
#
######
sub bam_free
{
# parameters
    my ($bam_ref,$trk,$sec) = @_;
# locals
    my ($freenum,$freemask);

# get current allocation for this track
    ($freenum,$freemask) = unpack  "Cb24", (substr $$bam_ref,(0x04+($trk-1)*4),4);

    if ((substr $freemask,$sec,1)="1") {
	return 0;
    }
    (substr $freemask,$sec,1) = "1";
    $freenum++;

# write new allocation for this track
    (substr $$bam_ref,(0x04+($trk-1)*4),4)=pack "Cb24", $freenum, $freemask;
    
    ($debug_g) && print "freed $trk,$sec\n";
    ($debug_g) && print "  $freenum $freemask\n";

# ok, return;
    return 1;
}

##########################################################################
#
# NAME  d64_read ()
#
# SYNOPSIS  $data = d64_read ($imagefile,$trk,$sec)
#  
# DESCRIPTION
#   Read data from a sector.
#
######
sub d64_read
{
# parameters
    my ($imagefile,$trk,$sec) = @_;
# locals
    my ($offset,$data);

# seek the right place
    $offset=ts_to_offset($trk,$sec);
    seek $imagefile, $offset, 0;

# read the sector
    read $imagefile, $data, 0x100;

    ($debug_g) && print "read: $trk,$sec\n";
# ok, return;
    return $data;
}

##########################################################################
#
# NAME  d64_write ()
#
# SYNOPSIS  d64_write ($imagefile,$trk,$sec,$data)
#  
# DESCRIPTION
#   Read data from a sector.
#
######
sub d64_write
{
# parameters
    my ($imagefile,$trk,$sec,$data) = @_;
# locals
    my $offset;

# seek the right place
    $offset=ts_to_offset($trk,$sec);
    seek $imagefile, $offset, 0;

# read the sector
    print $imagefile $data;

    ($debug_g) && print "write: $trk,$sec\n";
# ok, return;
    return;
}

##########################################################################
#
# NAME  ts_to_offset ()
#
# SYNOPSIS  $offset = ts_to_offset ($trk,$sec)
#  
# DESCRIPTION
#   Calculate the offset to a given track and sector.
#
######
sub ts_to_offset
{
# parameters
    my ($trk,$sec) = @_;
# locals
    my $offset;

# sum all sectors upto a track
    $offset=0;
    for (my $i=1; $i<$trk; $i++) {
	$offset+=$sectors_g[$i]*0x100;
    }

# add the sector offset.
    $offset+=$sec*0x100;

# ok, return;
    return $offset;
}

# eof
