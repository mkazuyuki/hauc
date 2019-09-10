#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our @iscsi_ip1;
our @iscsi_ip2;
our @iscsi_ip3;
our @iscsi_vname;
our @iscsi_pw;
our @dsname;
our $iscsi_fip;
require "./hauc.conf";

#-------------------------------------------------------------------------------
my $target	= "clpconf_iSCSI-Cluster/clp.conf";	#
#-------------------------------------------------------------------------------

# Globals
my @lines	= ();

# Main
#-------------------------------------------------------------------------------

for my $i (0..1) {
	$iscsi_ip1[$i] =~ s/\/\d*$//;
	$iscsi_ip2[$i] =~ s/\/\d*$//;
	$iscsi_ip3[$i] =~ s/\/\d*$//;
}

# Creating clp.conf
#---------------------------------------
my $file = "template/iSCSI/clp.conf";
open(IN, $file) or die "";
@lines = <IN>;
close(IN);
foreach (@lines) {
	s/%%IP11%%/$iscsi_ip1[0]/;
	s/%%IP12%%/$iscsi_ip2[0]/;
	s/%%IP13%%/$iscsi_ip3[0]/;
	s/%%IP21%%/$iscsi_ip1[1]/;
	s/%%IP22%%/$iscsi_ip2[1]/;
	s/%%IP23%%/$iscsi_ip3[1]/;
	s/%%FIP%%/$iscsi_fip/;
}
open(OUT, "> $target");
print OUT @lines;
close(OUT);

# Creating genw-remote-node
#---------------------------------------
$file = "template/iSCSI/genw-remote-node.pl";
open(IN, $file) or die "";
@lines = <IN>;
close(IN);
foreach (@lines) {
	s/%%VMDN1%%/$iscsi_vname[0]/;
	s/%%VMDN2%%/$iscsi_vname[1]/;
	s/%%VMIP1%%/$iscsi_ip1[0]/;
	s/%%VMIP2%%/$iscsi_ip1[1]/;
	s/%%VMK1%%/$esxi_ip[0]/;
	s/%%VMK2%%/$esxi_ip[1]/;
}
open(OUT, "> clpconf_iSCSI-Cluster/scripts/monitor.s/genw-remote-node/genw.sh");
print OUT @lines;
close(OUT);

# Copy files to the iSCSI VM#1
#---------------------------------------
if (&execution(".\\pscp.exe -l root -pw $iscsi_pw[0] -r clpconf_iSCSI-Cluster $iscsi_ip1[0]:/root/")) {
	exit 1;
}

# Check clp.conf
#---------------------------------------
my $cmd = ".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[0] $iscsi_ip1[0] ";
if (&execution($cmd . "clpcfctrl --compcheck -w -x ./clpconf_iSCSI-Cluster/")) {
	&Log("[E] #### CONFIGURATION IS INVALID ####\n");
	&Log("[E] #### CHECK YOUR PARAMETERS    ####\n");
	exit 1;
}

# Apply clp.conf
#---------------------------------------
#&execution($cmd . "clpcl --suspend");

if (&execution($cmd . "clpcfctrl --push -w -x ./clpconf_iSCSI-Cluster/")) {
	exit 1;
}
#&execution($cmd . "clpcl --resume");

# Reboot both VMs
#---------------------------------------
for my $i (0..1) {
	&execution(".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[$i] $iscsi_ip1[$i] reboot");
}

exit;

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	@lines = ();
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	while(<$h>){
		if (/Keyboard-interactive authentication prompts from server:/) { next; }
		elsif (/End of keyboard-interactive prompts from server/) { next; }
		chomp;
		&Log("[D] | $_\n");
		push (@lines, $_);
	}
	close($h);
	if ($?) {
		&Log(sprintf("[E]	result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	} else {
		&Log(sprintf("[D]	result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	}
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
