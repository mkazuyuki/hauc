#!/usr/bin/perl -w
#
# Network delay monitor
#
#	Issuing an alert when $threshold sec or more network delay was happend more than $times times in the last $term min.
#

use strict;
use warnings;
use Scalar::Util 'looks_like_number';

# Parameters
# ----------
my $term	= 15;   # min
my $threshold	= 1.0;  # sec
my $times	= 1;    # times
my $file	= "/opt/nec/clusterpro/perf/disk/nmp1.cur";
my $dev 	= "/dev/sda2";
# ----------

my @delay	= ();
my $cnt  	= 0;
my $msg  	= "";

open(IN, "tac $file | ");
while(<IN>){
	chomp;
	# retrieving "MDC HB Time, Max2"
	s/(\".*?\",){28}\"(.*?)\".*$/$2/;
	if (looks_like_number $_) {
		push (@delay, $_);
	}
	if($_ >= $threshold){
		$cnt++;
	}
	if(@delay >= $term){
		last;
	}
}
close(IN);

if ($cnt >= $times) {
	$msg .= "$threshold sec or more delay has been observed $cnt times in the last $term min. ";

	&RetrieveSyncDiff();
	&RetrieveDf(0);
	&RetrieveDf(1);

	system("clplogcmd -L WARN -m \"$msg\"");
}
print("clplogcmd -L WARN -m \"$msg\"");

# Retreaveing df (inode and 1K-blocks)
sub RetrieveDf {
	my $case = shift;
	if ($case) {
		open IN, "df    $dev | tail -n1 | awk '{print \$2, \$3, \$5}' |";
	} else {
		open IN, "df -i $dev | tail -n1 | awk '{print \$2, \$3, \$5}' |";
	}
	while (<IN>) {
		chomp;
		my $a = $_;
		my $b = $_;
		my $c = $_;
		$a =~ s/^(\d+?)\D.*$/$1/;
		$b =~ s/^(\d+?)\D+?(\d+?)\D.*$/$2/;
		$c =~ s/^.*?(\d*\%).*$/$1/;
		if ($case) {
			$msg .= "(1K-block use / total = $b / $a = $c) ";
		} else {
			$msg .= "(inode use / total = $b / $a = $c) ";
		}
	}
	close(IN);
}

# Retreaving SyncDiff, Cur (byte)
sub RetrieveSyncDiff {
	open(IN, "tail -n1 /opt/nec/clusterpro/perf/disk/nmp1.cur | ");
	while(<IN>){
		chomp;
		s/^(\".*?\",){19}\"(\d{1,})\".*$/$2/;
		$msg .= "(SyncDiff Cur = $_ byte) ";
	}
	close(IN);
}
