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
# my $mail	= "--mail";
my $mail	= "";
# ----------

my @delay	= ();
my $cnt  	= 0;
my $msg  	= "";

open(IN, "tac $file | ");
while(<IN>){
	chomp;
	# retrieving "MDC HB Time, Max2"
	s/^(\".*?\",){28}\"(.*?)\".*$/$2/;
	if (looks_like_number $_) {
		push (@delay, $_);
		if($_ >= $threshold){
			$cnt++;
		}
		if(@delay >= $term){
			last;
		}
	}
}
close(IN);

if ($cnt >= $times) {
	$msg .= "$threshold sec or more delay has been observed $cnt times in the last $term min. ";

	&RetrieveDf(0);
	&RetrieveDf(1);

	system("clplogcmd -L WARN $mail -m \"$msg\"");
}
print("$msg\n");

# Retreaveing df (inode and 1K-blocks)
sub RetrieveDf {
	my $case = shift;
	my $dksz = 0;
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
			$dksz = $a;
		} else {
			$msg .= "(inode use / total = $b / $a = $c) ";
		}
	}
	close(IN);
	if ($dksz){
		&RetrieveSyncDiff($dksz);
	}
}

# Retreaving SyncDiff, Cur (byte)
sub RetrieveSyncDiff {
	my $dkszKB = shift;
	open(IN, "tail -n1 $file | ");
	while(<IN>){
		chomp;
		s/^(\".*?\",){20}\"(\d{1,})\".*$/$2/;
		my $curKB = $_ / 1024;
		my $r = $curKB / $dkszKB * 100;
		$msg .= sprintf("(SyncDiff Cur / 1K-block total = %d / $dkszKB = %d%%)", $curKB, $r);
	}
	close(IN);
}
