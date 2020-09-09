#!/usr/bin/perl -w
#
# Network delay monitor
#
#	Issuing an alert when $threshold sec or more network delay was happend more than $times times in the last $term min.
#

# Parameters
# ----------
my $term	= 15;   # min
my $threshold	= 1.0;  # sec
my $times	= 1;    # times
my $file	= "/opt/nec/clusterpro/perf/disk/nmp1.cur";
# ----------

my @delay	= ();
my $cnt  	= 0;

open(IN, "tac $file | ");
while(<IN>){
	chomp;
	# retrieving "MDC HB Time, Max2"
	s/(\".*?\",){28}\"(\d{1,}\.\d{2})\".*$/$2/;
	push (@delay, $_);
	if($_ >= $threshold){
		$cnt++;
	}
	if(@delay >= $term){
		last;
	}
}
close(IN);
# print ("$threshold sec or more network delay has been observed $cnt times in the last $term min.\n");
if($cnt >= $times){
	# system("clplogcmd -L WARN        -m \"$threshold sec or more network delay has been observed $cnt times in the last $term min.\"");
	  system("clplogcmd -L WARN --mail -m \"$threshold sec or more network delay has been observed $cnt times in the last $term min.\"");
}
