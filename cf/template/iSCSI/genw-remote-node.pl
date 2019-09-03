#!/usr/bin/perl -w

#
# This monitors online status of CLP, VM on remote node.
# If CLP is offline and VM   is online, then starting CLP.
# If VM  is offline and ESXi is online, then starting VM.
# 

use strict;
use warnings;

#-------------------------------------------------------------------------------
# Configuration

# VM Display Name in the ESXi inventory and IP addresses of the VM
my $VMDN1	= '%%VMDN1%%';
my $VMIP1	= "%%VMIP1%%";

my $VMDN2	= '%%VMDN2%%';
my $VMIP2	= "%%VMIP2%%";

# IP address of VMKernel port
my $VMK1	= "%%VMK1%%";
my $VMK2	= "%%VMK2%%";
#-------------------------------------------------------------------------------

my $LOOPCNT	= 2;	# times
my $SLEEP	= 10;	# seconds
my @lines	= ();
my $noderemote	= "";
my $ret	= 0;

my $VMDN	= "";
my $VMIP	= "";
my $VMK 	= "";
my $tmp = `ip address | grep $VMIP1`;
if ($? == 0) {
	$VMDN	= $VMDN2;
	$VMIP = $VMIP2;
	$VMK = $VMK2;
} else {
	$VMDN	= $VMDN1;
	$VMIP = $VMIP1;
	$VMK = $VMK1;
}

for (my $i = 0; $i < $LOOPCNT; $i++){
	if (!&IsRemoteClpOffline()){
		# Remote ECX is online
		#&Log("[D] remote CLP [$VMIP] is online\n");
		exit 0;
	}
	sleep $SLEEP;
}

&Log("[D] remote CLP [$VMIP] is offline\n");
if (&execution("ping $VMIP -c1")) {
	&Log("[D] remote VM [$VMIP] is offline\n");
	if (&execution("ping $VMK -c1")) {
		&Log("[D] remote ESX [$VMK] is offline\n");
	} else {
		&Log("[D] remote ESX [$VMK] is online, starting VM\n");
		&PowerOnVM();
	}
} else {
	&Log("[D] remote VM [$noderemote:$VMIP] is online, starting CLP\n");
	&execution("clpcl -s -h $noderemote");
}

exit $ret;

#-------------------------------------------------------------------------------
sub PowerOnVM {
	#&Log("[I] Starting [$VMIP][$VMDN]\n");
	&execution("ssh -i ~/.ssh/id_rsa ${VMK} \"
		vmid=\\\$(vim-cmd vmsvc/getallvms 2>&1 | grep '${VMDN}' | awk '{print \\\$1}')
		logger -t expresscls \"start VM ID[\\\${vmid}]\" '[${VMDN}]'
		vim-cmd vmsvc/power.on \\\${vmid} 2>&1\"");

	foreach (@lines) {
		chomp;
		&Log("[D] \t$_\n");
	} 
	return 0;
}

#-------------------------------------------------------------------------------
sub IsRemoteClpOffline {
	my $nodelocal	= "";
	my $statremote	= "";

	&execution("clpstat");
	foreach(@lines){
		chomp;
		if (/^\s{4}(\S+?)\s.*: (.+?)\s/) {
			$noderemote = $1;
			$statremote = $2;
		}
		elsif (/<group>/){
			last;
		}
	}

	#&Log("[D] remote[$noderemote:$statremote]\n");
	if ($statremote eq "Offline") {
		return 1; # TRUE
	} else {
		return 0; # FALSE
	}
}

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;
	#foreach (@lines) {
	#	chomp;
	#	&Log("[D]\t$_\n");
	#} 
	close($h); 
	&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
}

#-------------------------------------------------------------------------------
sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
