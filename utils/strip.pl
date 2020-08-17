#! /usr/bin/perl -w
##########################################################################
#
# FILE  strip.pl
# Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
# Written by Daniel Kahlin <daniel@kahlin.net>
# $Id: strip.pl,v 1.6 2003/08/26 17:23:51 tlr Exp $
#
# DESCRIPTION
#
#
######
use strict;
use Getopt::Long qw(:config no_ignore_case bundling);

my $PROGRAM="strip.pl";
my $PROGRAM_VERSION="0.0.1";

# globals
my $debug_g;
my $verbose_g;
my $strip_g;
my $linenum_g;
my $line_g;
my $outlinenum_g;
my %defines_g;

##########################################################################
#
# the MAIN code
#
# checks command line arguments
# prints help if appropriate, calls process_file() for
# all specified files.
#
######
my $file;
my @defines=();
my @undefines=();
my $outputfile="out.asm";
my $version;
my $help;

GetOptions(
    'D=s' => \@defines,
    'U=s' => \@undefines,
    's' => \$strip_g,
    'o=s' => \$outputfile,
    'v' => \$verbose_g,
    'd' => \$debug_g,
    'V' => \$version,
    'h' => \$help
);


# print version and exit if -V
if ($version) {
    print $PROGRAM," ",$PROGRAM_VERSION,"\n";
    exit 0;
}

# print help and exit if -h
if ($help) {
    print <<EOF;
$PROGRAM $PROGRAM_VERSION - strips a dasm input file.
Copyright (c) 2003 Daniel Kahlin <daniel\@kahlin.net>

USAGE: $PROGRAM [-D <label>][-U <label>][-s][-o <name>][-h][-V][-v][-d] <file>
  -D make <label> defined.
  -U make <label> undefined.
  -s strip comments
  -o <name> set output filename
  -h display this help text
  -V display version
  -v be verbose
  -d dump lots of (weird) debugging info
EOF
    exit 0;
}


#
# Ok, start the main program.
#
($file=shift @ARGV) or die $PROGRAM, ": missing filename\n";


# setup defines and undefines
# '1' means defined.
# '0' means undefined.
# 'undef' means undetermined.
my $thisdef;
foreach $thisdef (@defines) {
    $defines_g{$thisdef}=1;
    ($verbose_g) && print "defined '$thisdef'\n";
}
foreach $thisdef (@undefines) {
    $defines_g{$thisdef}=0;
    ($verbose_g) && print "undefined '$thisdef'\n";
}

##########################################################################
#
# DESCRIPTION
#   assemble an the file.
#
######
process_file($file,$outputfile);
($verbose_g) && print "processed $linenum_g lines of code into $outlinenum_g lines.\n";
exit 0;


##########################################################################
#
# NAME  process_file ()
#
# DESCRIPTION
#   assemble an input file.
#   $pass determines what to do.  
#     1=define labels
#     2=assemble code
#
######
sub process_file
{
# parameters
    my ($file, $outfile) = @_;
# locals
    my ($empty_flag,$output_flag,$output_inhibit,$mnemonic,$operand);
    # ifstack contains the encountered conditionals.  
    # 'undef' means not evaluated, '1' means true, '0' means false.
    my @ifstack=(undef);

    open(OUT, "> $outfile") || die $PROGRAM, ": could not open output file\n";

    $linenum_g=0;
    $line_g="";
    open(IN, "< $file") || die $PROGRAM, ": could not open input file\n";
    $linenum_g=0;
    while (<IN>) {
	$linenum_g++;
	$line_g=$_;
	(s/\;(.*)$//);        # skip trailing comments
	(s/\s*$//);           # skip trailing white space
	# skip lines that are empty after initial processing
	$empty_flag = (/^\s*$/);

	$output_inhibit=0;
	if (!$empty_flag) {
	    $mnemonic=(s/^\s+([a-zA-Z][a-zA-Z0-9\.]*)//)?$1:"";
	    $operand=(s/^\s+(.*?)\s*$//)?$1:"";

	    if ($mnemonic eq "IF") {
		($debug_g) && print "found: IF\n";
		# push undef on IF.
		push @ifstack,undef;
	    } elsif ($mnemonic eq "IFCONST" || $mnemonic eq "IFNCONST") {
		($debug_g) && print "found: IF[N]CONST\n";
		# if defined, push condition, else push undef.
		if (defined $defines_g{$operand}) {
		    if ($defines_g{$operand}) {
			push @ifstack,($mnemonic eq "IFCONST");
		    } else {
			push @ifstack,($mnemonic eq "IFNCONST");
		    }
		    ($debug_g) && print "found: $operand\n";
		    $output_inhibit=1;
		} else {
		    push @ifstack,undef;
		}
	    } elsif ($mnemonic eq "ELSE") {
		($debug_g) && print "found: ELSE\n";
		# invert condition if defined
		if (defined $ifstack[$#ifstack]) {
		    $ifstack[$#ifstack]=!$ifstack[$#ifstack];
		    $output_inhibit=1;
		}
	    } elsif ($mnemonic eq "ENDIF" || $mnemonic eq "EIF") {
		($debug_g) && print "found: ENDIF\n";
		if (defined $ifstack[$#ifstack]) {
		    $output_inhibit=1;
		}
		pop @ifstack;
	    }

	}

	# traverse @ifstack from the bottom to determine if we should output
	# anything.
	# if a '0' is encountered, output is turned of.
	# this is done for every line, so it's not very efficient
	$output_flag=1;
	for (my $i=0; $i<=$#ifstack; $i++) {
	    if (defined $ifstack[$i] && $ifstack[$i]==0) {
		$output_flag=0;
	    }
	}

	# send lines to the output file
	# if $output_inhibit is '1' skip this line.
	if (!$output_inhibit && $output_flag && (!$strip_g || !$empty_flag)) {
	    # output the line
	    print OUT $line_g;
	    $outlinenum_g++;
	}
    }

    # all done, close files
    close(IN);
    close(OUT);

    # return safely to earth!
    return;
}

# eof
