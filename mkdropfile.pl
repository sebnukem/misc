#!/usr/bin/perl -w
# Create a package drop file from a list of property ids

use strict;
use Getopt::Long;

sub usage() {
	return <<'EOU';
Generate a dropfile to create packages for CG.
Property IDs can be provided from arguments, stdin, or a file. No specific format required.

Usage:
  mkdropfile.pl PID ..
  mkdropfile.pl OPTIONS -x PID ..
  echo PID .. | mkdropfile.pl
  cat PIDSFILE | mkdropfile.pl
  mkdropfile.pl < PIDSFILE
  mkdropfile.pl -i PIDSFILE

  mkdropfile OPTIONS:
    -s, --section INT ..    specifiy Section IDs, defaults to 0 (all sections)
    -l, --langid INT ..     specify Lang IDs, defaults to 0 (all langs)
    -p, --priority INT      specify Priority, default 1
    -g, --generationlevel INT ..  specify Onwer Type Ids, default 1
    -t, --tag STRING ..     specify Tagnames, default null (all tags)
    -q, --qid, --queue INT  specify Queue ID, default 4
    -i, --input FILENAME    read Property IDs from file
    -o, --output FILENAME   output file name

Example:
  mkdropfile.pl -s 12 13 14 -l 1033 -p 20 -g 1 2 -t Prod -q 2 -x 1345 67853 112345

EOU
}
die usage() if -t STDIN && $#ARGV < 0;

my $help = 0;
my @sections = ();
my @langs = ();
my $priority = '1';
my @genlevels = ();
my @tags = ();
my $queue = '4';
my $inputfilename;
my $outputfilename = "Hotel2TriggerEnhanced.txt";
my @pids = ();
GetOptions('help' => \$help,
	'section|secid=i{1,}' => \@sections,
	'language|langid=i{1,}' => \@langs,
	'priority=i' => \$priority,
	'generationlevel=i{1,4}' => \@genlevels,
	'tags=s{1,}' => \@tags,
	'qid|queue=i' => \$queue,
	'input=s' => \$inputfilename,
	'ouput=s' => \$outputfilename,
	'x=i{1,}' => \@pids
	) or die usage();

if ($help) { print usage(); exit 0; }
@sections = @sections ? sort(uniq(@sections)) : ('0');
@langs = @langs ? sort(uniq(@langs)) : ('0');
@genlevels = @genlevels ? sort(uniq(@genlevels)) : ('1');
@tags = @tags ? sort(uniq(@tags)) : ('');

if ($inputfilename) { # read input file
	open my $ifile, "<", $inputfilename;
	while (<$ifile>) {
		chomp;
		next unless $_;
		my @a = split /\D/;
		push @pids, shift @a while @a;
}	}
push @pids, shift while @ARGV; # read no-opt args
if (! -t STDIN) { # we have STDIN piped not from terminal
	while (<>) { # read STDIN
		chomp;
		next unless $_;
		my @a = split /\D/;
		push @pids, shift @a while @a;
}	}
@pids = grep(/\d/, sort(uniq(@pids))) if @pids;

my ($pidn, $sectionn, $langn, $genleveln, $tagn) = (scalar(@pids), scalar(@sections), scalar(@langs), scalar(@genlevels), scalar(@tags));

print "generating ". $pidn * $sectionn * $langn * $genleveln * $tagn . " row dropfile for:\n";
print " $pidn properties: @pids\n";
print " $sectionn sections: @sections\n";
print " $langn langs: @langs\n";
print " $genleveln gen levels: @genlevels\n";
print " $tagn tags: @tags\n";
print " priority: $priority\n";
print " qid: $queue\n";
die "no properties, exiting" if !$pidn;

open my $ofile, ">:raw:encoding(UTF16-LE):crlf:utf8", $outputfilename;
print $ofile "\x{FEFF}";
print $ofile "PropertyID\tSection\tLanguage\tPriority\tDateToBeGenerated\tGenerationLevel\tTagName\tQueueID";
foreach my $pid (@pids) {
	foreach my $section (@sections) {
		foreach my $lang (@langs) {
			foreach my $genlevel (@genlevels) {
				foreach my $tag (@tags) {
					print $ofile "\n$pid\t$section\t$lang\t$priority\t\t$genlevel\t$tag\t$queue";
}	}	}	}	}
close $ofile;

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

