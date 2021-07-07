#!perl.exe

#
# This script creats VMs for iSCSI and vMA Cluster
#

use strict;
use warnings;
use POSIX qw(floor ceil);

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our $advertised_hdd_size;
our $managed_vmdk_size;
our @iscsi_ds;
our @iscsi_vname;	# iSCSI VM Name

require "./hauc.conf" or die "file not found hauc.conf";

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();
my $iscsi_size = ceil(1.5868 * $managed_vmdk_size + 1.3353);
$iscsi_size = $iscsi_size . "G";

&Log("Advertised HDD Size       (specified)  = ${advertised_hdd_size}G\n");
&Log("Managed VMs Total Size    (specified)  = ${managed_vmdk_size}G\n");
&Log("Minimum Required HDD Size (calculated) = " . floor($managed_vmdk_size * 1.8484 + 24.532) . "G\n");
&Log("iSCSI[1|2]_1.vmdk will be (calculated) = $iscsi_size\n");

if ( floor($managed_vmdk_size * 1.8484 + 24.532) > $advertised_hdd_size ) {
	print("ERROR: Your input for 'Advertised HDD Size'($advertised_hdd_size GB) is too small to accomodate your specified 'Total Size of Managed Thick-Provisioned VMs ($managed_vmdk_size GB)'.\nNOTE : An additional 33% is automatically allocated as Initial Freespace for the datastore after deployment of the VMs, so you have two choices:\n\n  1) You can increase the 'Advertised HDD Size' by acquiring additional physical storage or\n  2) You can reduce your specified 'Total Size of Managed Thick-Provisioned VMs' by as much as 15% or 20%, with the understanding that the mirrored iSCSI datastore will be left with less than 33% Initial Freespace for future expansion.\n\nPush return key");
	my $tmp = <STDIN>;
	exit 1;
}

# Main
#-------------------------------------------------------------------------------
for my $i (0..1) {
	# Specifying Datastore size
	my @buf = ();
	for my $i (0..1) {
		my $file = "ESXi-scripts/cf-iscsi-" . ($i+1) . ".sh";
		open(IN, $file) or die "Couldn't open file $file, $!";
		@buf = <IN>;
		close(IN);
		foreach(@buf){
			s/^VM_DISK_SIZE2=.*$/VM_DISK_SIZE2=${iscsi_size}/;
			s/^DATASTORE_PATH=.*/DATASTORE_PATH=\/vmfs\/volumes\/${iscsi_ds[$i]}/;
		}
		open(OUT, "> ${file}") or die "Couldn't open file $file, $!";
		print OUT @buf;
		close(OUT);
	}

	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";

	# Creating iSCSI VM
	if (&execution($cmd . "-m ESXi-scripts/cf-iscsi-" . ($i + 1) .".sh")) {
		&Log("[E] Failed to create iSCSI" . ($i+1) . "\n");
	}
	&Log("[I] iSCSI". ($i+1) . " created\n");
}
# Validation
for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";
	&execution("$cmd vim-cmd vmsvc/getallvms");
	my $found = 0;
	foreach (@lines) {
		if (/ $iscsi_vname[$i] /) {
			$found = 1;
			last;
		}
	}
	if (!$found) {
		&Log("[E] *******************************************************\n");
		&Log("[E] On ESXi#" . ($i+1) . ", [$n] was not found.\n");
		&Log("[E] Check your configuration.\n");
		&Log("[E] Push return key\n");
		&Log("[E] *******************************************************\n");
		my $tmp = <STDIN>;
		exit;
	}
}
&Log("[I] ***********************************************\n");
&Log("[I] All iSCSI VMs were found in right ESXi.\n");
&Log("[I] This phase was successfully completed.\n");
&Log("[I] Push return key\n");
&Log("[I] ***********************************************\n");
my $tmp = <STDIN>;
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
		&Log(sprintf("[E] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	} else {
		&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
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

	open(LOG, ">> phase2.log");
	print LOG "$date $_[0]";
	close(LOG);

	return 0;
}
