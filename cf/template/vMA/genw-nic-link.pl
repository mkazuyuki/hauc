#!/usr/bin/perl -w
#
# Monitoring script for uplink status of vSwitch
# This sicript returns 1 if all the uplink of the vSwitch are Down.
#
use strict;

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
# IP addresses of VMkernel port.
my $vmk1 = "%%VMK1%%";
my $vmk2 = "%%VMK2%%";

# IP address of vMA nodes
my $vma1 = "%%VMA1%%";
my $vma2 = "%%VMA2%%";

# vSwitch to be monitored its link status
my @vsws = ("vSwitch0", "%%VSWITCH%%");


#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
my $vmk = "";
my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk = $vmk1;
} else {
	$tmp = `ip address | grep $vma2`;
	if ($? == 0) {
		$vmk = $vmk2;
	} else {
		&Log("[E] Invalid configuration (Mananegment host IP could not be found).\n");
		exit 1;
	}
}

my @lines = ();
$ENV{"HOME"} = "/root";

# uniq @vsws
my %cnts;
@vsws = grep (!$cnts{$_}, @vsws);

foreach (@vsws) {
	if (&monitor($_)){
		exit 1;
	}
}
exit 0;

#-------------------------------------------------------------------------------
sub monitor {
	my $vsw = shift;
	my $cmd = "ssh $vmk esxcli network vswitch standard list --vswitch-name='$vsw' | grep Uplinks";
	if (&execution($cmd)){
		exit 1;
	}
	my @nics = ();
	if (@lines == 0) {
		&Log ("[D] vSwitch [$vsw] may not exist\n");
		return 0;
	} elsif ($lines[0] =~ /Uplinks:\s*$/) {
		&Log ("[E] No uplink found\n");
		exit 1;
	} elsif ($lines[0] =~ /, /) {
		$lines[0] =~ s/.*Uplinks:\s*//;
		@nics = split(/, /, $lines[0]);
	} else {
		$lines[0] =~ s/.*Uplinks:\s*//;
		push @nics, $lines[0];
	}
	my $cnt = 0;
	foreach (@nics){
		$cmd = "ssh $vmk esxcli network nic list | grep $_ | awk {'print \$5'}";
		if (&execution($cmd)) {
			exit 1;
		} elsif ($lines[0] eq "Up") {
			# NIC Link UP
			return 0;
		} elsif ($lines[0] eq "Down") {
			# NIC Link DOWN
			$cnt++;
		}
	}
	#print "cnt = $cnt  \$#nics = $#nics\n";
	if ($cnt == $#nics + 1){
		&Log("[E] vSwith [$vsw] lost all uplink\n");
		return 1;
	}
	return 0;
}

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;

	foreach (@lines) {
		chomp;
		&Log("[D] \t$_\n");
	}

	close($h);
	&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
}

#-------------------------------------------------------------------------------
sub Log {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
