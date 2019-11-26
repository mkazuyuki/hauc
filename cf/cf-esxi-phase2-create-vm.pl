#!perl.exe

#
# This script creats VMs for iSCSI and vMA Cluster
#

use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our $advertised_hdd_size;
our $safety_margin;
our @iscsi_ds;
our @iscsi_vname;	# iSCSI VM Name
our @vma_vname;	# vMA VM Name

require "./hauc.conf" or die "file not found hauc.conf";

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();

# Calculating device size of iSCSI Datastore
# 	$iscsi_size
# 	= int( { ( { (Advertised HDD size in GB) * 0.9313 GiB/GB * Safety Margin} * { (1 - 5% of VMFS overhead) * Safety Margin } ) - ( .vswp + logs etc. + sda of vMA VM in GB ) - ( .vswp + log etc. + sda of iSCSI VM in GB ) } * Safety Margin)
# 	= int({({(Advertised HDD size in GB) * 0.9313 * 0.99} * {0.95 * 0.99}) - (2+0.2+6) - (2+0.2+9)} * 0.99)
$safety_margin =~ s/\%//;
$safety_margin = 1 - ($safety_margin/100);
my $iscsi_size = int ((($advertised_hdd_size * 0.9313 * $safety_margin) * (0.95 * $safety_margin) - (2+0.2+6) - (2+0.2+9)) * $safety_margin);
$iscsi_size = $iscsi_size . "G";

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

	# Creating vMA VM
	if (&execution($cmd . "-m ESXi-scripts/cf-vma-" . ($i + 1) .".sh")) {
		&Log("[E] Failed to create vMA" . ($i+1) . "\n");
	}
	&Log("[I] vMA" . ($i+1) . " created\n");

}
# Validation
my @vms = (	[ $iscsi_vname[0], $vma_vname[0] ],
		[ $iscsi_vname[1], $vma_vname[1] ] );
for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";
	&execution("$cmd vim-cmd vmsvc/getallvms");
	foreach my $n ( @{$vms[$i]} ) {
		my $found = 0;
		foreach (@lines) {
			if (/ $n /) {
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
}
&Log("[I] ***********************************************\n");
&Log("[I] All iSCSI and vMA VMs were found in right ESXi.\n");
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
