#! /usr/bin/perl -w
##########################################################################
#
# FILE  pitchtab.pl
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: pitchtab.pl,v 1.1 2003/06/17 19:28:59 tlr Exp $
#
# DESCRIPTION
#   Calculates pitches for the vic20.
#
#   Calculation formulas from (1):
#     MOS6560 (NTSC-M) Clock 14318181/14 Hz
#     MOS6561 (PAL-B)  Clock 4433618/4 Hz
#     f=clk/div/(128-((reg+1)&127))
#     (where div is 256 for the bass, 128 for alto, 64 for soprano and
#      32 for noise)
#
#   From the book "A Pocket Handbook for the VIC" (2):
#     C   C#  D   D#  E   F   F#  G   G#  A   A#  B
#     135,143,147,151,159,163,167,175,179,183,187,191
#     195,199,201,203,207,209,212,215,217,219,221,223
#     225,227,228,229,231,232,233,235,236,237,238,239
#     240,241
#
#   From the book "VIC REVEALED" (3):
#     C   C#  D   D#  E   F   F#  G   G#  A   A#  B
#     128,134,141,147,153,159,164,170,174,179,183,187
#     191,195,198,201,204,207,210,213,215,217,219,221
#     223,225,227,228,230,231,232,234,235,236,237,238
#     239,240
#     This is almost obtained by using:
#      PAL-B, f_a4=458.7 or NTSC-M, f_at
#
# REFERENCES
#   (1) Marko Mäkelä "VIC-I.txt", Revision 1.2, February 1998
#   (2) Peter Gerrard & Danny Doyle "A Pocket Handbook for the VIC",
#       1984, Duckworth, ISBN 0-7156-1786-9
#   (3) Nick Hampshire "VIC REVEALED", Second impression, June 1983,
#       Duckworth, ISBN 0-7156-1699-4
#
######
use strict;
use Getopt::Std;

my $PROGRAM="pitchtab.pl";
my $PROGRAM_VERSION="0.0.1";


# globals
my $debug_g;
my $verbose_g;
my $n_low_g=60-12; #midi c3
my $n_high_g=60+24+1; #midi c#5
my $f_ref_g=425; 
my $n_ref_g=69; #midi a4

#
# the MAIN code
#
# checks command line arguments
#

my %opts;
getopts ('vdh',\%opts);

$debug_g=$opts{d};
$verbose_g=$opts{v};


# print help and exit if -h
if ($opts{h}) {
    print <<EOF;
USAGE: pitchtab.pl [-h][-v][-d]
  -h display this help text
  -d dump lots of (weird) debugging info
EOF
    exit 0;
}

#
#
#

my $phi2;
my $freq;
my $newfreq;
my $reg;
my $note;
# PAL
#$phi2=4433618/4;
# NTSC
$phi2=14318181/14;
print "6560 sound value calulator\n";
printf "PAL (phi2=%.2fHz)\n",$phi2;
for ($note=$n_low_g; $note<=$n_high_g; $note++) {
    $freq=note_to_freq($note);
    $reg=freq_to_reg($phi2,64,$freq);
    $newfreq=reg_to_freq($phi2,64,$reg);
    printf "%d (0x%02x) %.2fHz (%.2fHz)\n",$reg+128,$reg+128,$newfreq,$freq;
}


sub note_to_freq
{
    my ($note)=@_;
    my $freq;

    $freq=$f_ref_g*(2**(($note-$n_ref_g)/12));
    return $freq;
}

sub reg_to_freq
{
    my ($phi2,$div,$reg)=@_;
    my $freq;

    $freq=($phi2/$div)/(0x80-(($reg+1) & 0x7f));
#    $freq=($phi2/$div)/(0x80-(($reg) & 0x7f));
    return $freq;
}

sub freq_to_reg
{
    my ($phi2,$div,$freq)=@_;
    my $tmp;
    my $reg;

    #$freq=($phi2/$div)/(0x80-(($reg+1) & 0x7f));
    $tmp=0x80-($phi2/($div*$freq));
    $reg=($tmp & 0x7f) - 1; 
#    $reg=($tmp & 0x7f); 
    return int($reg+0.5);
}
# eof
