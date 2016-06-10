#!/usr/bin/perl -w
# Create a package drop file from a list of property ids
# author: snicoud@expedia.com

use strict;
use Getopt::Long;
my $app = $0; $app =~ s=.*/==;

sub usage() {
	return <<"EOU";
Generate a dropfile to create packages for CG.
Property IDs can be provided from arguments, stdin, or a file. No specific format required.

Usage:
  $app PID ..
  $app OPTIONS -x PID ..
  echo PID .. | $app
  cat PIDSFILE | $app
  $app < PIDSFILE
  $app -i PIDSFILE

  $app OPTIONS:
    -s, --section INT ..    specifiy Section IDs, defaults to 0 (all sections)
    -l, --langid INT ..     specify Lang IDs, defaults to 0 (all langs)
    -p, --priority INT      specify Priority, default 1
    -g, --generationlevel INT ..  specify Onwer Type Ids, default 1
    -t, --tag STRING ..     specify Tagnames, default null (all tags)
    -q, --qid, --queue INT  specify Queue ID, default 1
    -i, --input FILENAME    read Property IDs from file
    -o, --output FILENAME   output file name

Example:
  $app -s 12 13 14 -l 1033 -p 20 -g 1 2 -t Prod -q 2 -x 1345 67853 112345

EOU
}
die usage() if -t STDIN && $#ARGV < 0;

my (undef, $mm, $hh, $dd, $mo, $yy) = (localtime())[0..5];
$mo++; $yy =~ s/\d\d?(\d\d)/$1/;
my $ts = sprintf "%02d%02d%02d%02d%02d", $yy, $mo, $dd, $hh, $mm;
my $help = 0;
my @sections = ();
my @langs = ();
my $priority = '1'; # default
my @genlevels = ();
my @tags = ();
my $queue = '1'; # default
my $inputfilename;
my $outputprefixname = "Hotel2TriggerEnhanced";
my $outputfilename = "${outputprefixname}_${ts}.txt"; # default
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
@sections = @sections ? sort {$a <=> $b} uniq(@sections) : ('0'); # default
@langs = @langs ? sort {$a <=> $b} uniq(@langs) : ('0'); # default
@genlevels = @genlevels ? sort {$a <=> $b} uniq(@genlevels) : ('1'); # default
@tags = @tags ? sort(uniq(@tags)) : (''); # default
$outputfilename = "$outputprefixname$outputfilename" if $outputfilename =~ /^_/; # prepend prefix if provided name starts with _
$outputfilename = "$outputfilename.txt" unless $outputfilename =~ /\.txt$/; # append .txt if missing

if ($inputfilename) { # read pids input file
	open my $ifile, "<", $inputfilename;
	while (<$ifile>) {
		chomp;
		next unless $_;
		my @a = split /\D/;
		push @pids, shift @a while @a;
}	}
push @pids, shift while @ARGV; # read pids no-opt args
if (! -t STDIN) { # STDIN piped not from terminal
	while (<>) { # read pids STDIN
		chomp;
		next unless $_;
		my @a = split /\D/;
		push @pids, shift @a while @a;
}	}
@pids = sort {$a <=> $b} grep(/\d/, uniq(@pids)) if @pids;

my ($pidn, $sectionn, $langn, $genleveln, $tagn) = (scalar(@pids), scalar(@sections), scalar(@langs), scalar(@genlevels), scalar(@tags));
my $rown = $pidn * $sectionn * $langn * $genleveln * $tagn;
print <<"EOP";
generating $rown-row dropfile for:
$pidn properties: @pids
$sectionn sections: @sections
$langn langs: @langs
$genleveln gen levels: @genlevels
$tagn tags: @tags
  priority: $priority
  qid: $queue
EOP
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
print "done"; system("wc -l $outputfilename");

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

