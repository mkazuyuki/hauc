#!/usr/bin/perl -w
#
# Script for monitoring the Virtual Machine on standby ESXi
# - This tries to recover the iSCSI session of the ESXi which the vMA (specified as $vma1, $vma2) is running on.
#   It is a countermeasure for that iSCSI Software Adapter on the ESXi cannot recover the iSCSI session after a boot of the ESXi.
# - This tires to clan up invalid VMs and the VMs on the specified Datastore which are registerd on the inventory of standby ESXi.
#   It is a countermeasure for that VM(s) which is in "invalid" or "power off" status left on the standby ESXi inventory after reboot on crash of the ESXi.

use strict;

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
my $DatastoreName = "%%DATASTORE%%";

# IP address for VMkernel port
my $vmk1 = "%%VMK1%%";
my $vmk2 = "%%VMK2%%";

# IP address for vMA VMs
my $vma1 = "%%VMA1%%";
my $vma2 = "%%VMA2%%";

# Device name of iSCSI Software Adapter on ESXi-1 and ESXi-2 
my $vmhba1 = "%%VMHBA1%%";
my $vmhba2 = "%%VMHBA2%%";
#-------------------------------------------------------------------------------

# This line need for correct execution of vmware-cmd w/o password
$ENV{"HOME"} = "/root";

my $vmk = "";	# vmk local
my $vmkr = "";	# vmk remote
my $vmhba = "";
my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk = $vmk1;
	$vmkr = $vmk2;
	$vmhba = $vmhba1;
} else {
	$vmk = $vmk2;
	$vmkr = $vmk1;
	$vmhba = $vmhba2;
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
my @lines	= ();
&iscsiRecovery();
my $val = &Monitor();
exit $val;

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub iscsiRecovery{
	my $ret = -1;
	my $cmd = "ssh $vmk esxcli iscsi session list --adapter=$vmhba";
	&execution($cmd);
	foreach(@lines){
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
		if (/$vmhba/){
			$ret = 0;
			last;
		}
	}
	if ($ret == 0){
		return 0;
	} else {
		&Log("[I][iscsiRecovery] no session with [$vmhba] found\n");
	}
	
	$cmd = "ssh $vmk esxcli iscsi session add --adapter=$vmhba";
	$ret = &execution($cmd);
	foreach(@lines){
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
	}
	return $ret;	
}

sub Monitor{
	my %vmx;	# path to .vmx file
	my %vmxr;	# path to .vmx file in REMOTE
	my @vmpo;	# VMs which are in power off state
	my @vmiv;	# VMs which are in invalid status

	# Finding out registered VMs in iSCSI datastore on LOCAL node
	my $cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/getallvms 2>&1\"";
	&execution($cmd);
	foreach $a (@lines){
		chomp $a;
		#&Log("[D]! \t[$a]\n");
		if ($a =~ /^(\d+).*\[$DatastoreName\] (.+\.vmx)/){
			$vmx{$1} = $2;
			&Log("[D] on LOCAL [$vmk] [$1][$2] exists\n");
		}
		elsif ($a =~ /^Skipping invalid VM '(\d.+)'/){
			push(@vmiv, $1);
			&Log("[I] on LOCAL  [$vmk] VM ID [$1] exists as invalid VM\n");
		}
	}

	foreach (@vmiv){
		$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/unregister $_ 2>&1\"";
		&execution($cmd);
		foreach $b (@lines){
			chomp $b;
			&Log("[D] \t$b\n");
		}
		&Log("[I] on LOCAL  [$vmk] VM ID [$_] was unregistered\n");
		execution("clplogcmd -m \"invalid VM ID [$_] was unregistered on [$vmk]\n\"");
	}

	# Checking Powerstatus of each registered VMs on Local node
	foreach $a (keys %vmx) {
		$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/power.getstate $a 2>&1\"";
		&execution($cmd);
		foreach (@lines){
			if(/Powered off/){
				&Log("[W] on LOCAL  [$vmk] [$a][$vmx{$a}] was in Powered off status\n");
				push (@vmpo, $a);
			}
			#elsif(/Powered on/){
			#	&Log("[W] on LOCAL  [$vmk] [$a][$vmx{$a}] was in Powered on status\n");
			#}
		}
	}

	# Finding out registered VMs in iSCSI datastore on REMOTE node
	if ($#vmpo == -1) {return 0;}
	$cmd  = "ssh -i ~/.ssh/id_rsa $vmkr \"vim-cmd vmsvc/getallvms 2>&1\"";
	&execution($cmd);
	foreach(@lines){
		if (/^(\d+).*\[$DatastoreName\] (.+\.vmx)/){
			$vmxr{$1} = $2;
			&Log("[D] on REMOTE [$vmkr] [$1][$2] exists\n");
		}
	}
	# Unregistering LOCAL VM if REMOTE VM is ONLINE
	foreach $a (@vmpo){
		foreach $b (keys %vmxr){
			if ($vmx{$a} eq $vmxr{$b}){
				my $tmp = 0;
				$cmd = "ssh -i ~/.ssh/id_rsa $vmkr \"vim-cmd vmsvc/power.getstate $b 2>&1\"";
				&execution($cmd);
				foreach(@lines){
					chomp;
					&Log("[D] \t$_\n");
					if(/Powered on/){
						$tmp = 1;
					}
				}
				if ($tmp) {
					$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/unregister $a 2>&1\"";
					&execution($cmd);
					foreach(@lines){
						chomp;
						&Log("[D] \t$_\n");
					}
					&Log("[I] on LOCAL  [$vmk] [$a][$vmx{$a}] was unregistered\n");
					execution("clplogcmd -m \"VM [$vmx{$a}][$a] was unregistered on [$vmk]\n\"");
				} else {
					&Log("[D] on LOCAL  [$vmk] do nothing for [$a][$vmx{$a}]\n");
				}
			}
		}
	}
	return 0;
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
	&Log(sprintf("[D] result    ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	#&Log(sprintf("[D] executing ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
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
