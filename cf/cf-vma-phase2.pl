#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');		# ESXi IP address
my @esxi_pw	= ('NEC123nec!', 'NEC123nec!');			# ESXi root password
my @vma_ip	= ('172.31.255.6', '172.31.255.7');	# vMA IP address and Net Mask
my @vma_vname	= ('vMA1', 'vMA2');				# vMA VM Name
my @vma_pw	= ('NEC123nec!', 'NEC123nec!');			# vMA root password
#-------------------------------------------------------------------------------

# Globals
my $devid	= 3000;	# CDROM Device ID of the VM. It can be obtained by "vim-cmd vmsvc/device.getdevices $VMID".
my @lines	= ();

# Main
#-------------------------------------------------------------------------------
# Connecting DVD Drive to the VMs
&connectDVD;

for my $i (0..1) {
	&execution(".\\pscp.exe -l root -pw $vma_pw[$i] expresscls-4.1.1-1.x86_64.rpm $vma_ip[$i]:/root/");
	&execution(".\\pscp.exe -l root -pw $vma_pw[$i] ECX4.x-lin1.key $vma_ip[$i]:/root/");

	my $cmd = ".\\plink.exe -no-antispoof -l root -pw $vma_pw[$i] $vma_ip[$i] ";
	&execution($cmd . "\"mkdir /media/cdrom; mount /dev/cdrom /media/cdrom\"");
	&execution($cmd . "\"yum --disablerepo=* --enablerepo=c7-media install -y targetcli targetd perl\"");
	&execution($cmd . "\"hostnamectl set-hostname vma" . ($i+1) . "\"");
	&execution($cmd . "\"systemctl stop firewalld.service; systemctl disable firewalld.service\"");
	&execution($cmd . "\"sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config\"");
	&execution($cmd . "\"yes no | ssh-keygen -t rsa -f /root/.ssh/id_rsa -N \\\"\\\"\"");
	&execution($cmd . "\"umount /media/cdrom\"");

	&execution($cmd . "\"rpm -ivh /root/expresscls*.rpm\"");
	&execution($cmd . "\"clplcnsc -i ECX4.x-lin1.key\"");
	&execution($cmd . "\"rm expresscls\*.rpm ECX4.x-\*.key\"");

	&execution($cmd . "reboot");
}
#-------------------------------------------------------------------------------
sub connectDVD {
	for my $i (0..1) {
		my $cmd0 = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] ";
		my $cmd = $cmd0 . "\"VMID=`vim-cmd vmsvc/getallvms | grep \\\" $vma_vname[$i] \\\" | awk '{print \$1}'`; vim-cmd vmsvc/device.getdevices \$VMID\"";
		&execution($cmd);
		my $j;
		my $k;
		for ($j = 0; $j < $#lines; $j++) {
			if ($lines[$j] =~ /      \(vim.vm.device.VirtualCdrom\) \{/){
				last;
			}
		}
		for ($k = $j; $k < $#lines; $k++) {
			# print "|| $lines[$k]\n";
			if ($lines[$k] =~ /^            connected = true,/){
				&Log("[D] DVD Drive is in connected status.\n");
				last;
			}
			elsif ($lines[$k] =~ /^            connected = false,/){
				&Log("[I] DVD Drive is in disconnected status. Connecting DVD Drive.\n");
				$cmd = $cmd0 . "\"VMID=`vim-cmd vmsvc/getallvms | grep \\\" $vma_vname[$i] \\\" | awk '{print \\\$1}'`; vim-cmd vmsvc/device.connection \$VMID $devid true\"";
				&execution($cmd);
				last;
			}
			elsif ($lines[$k] =~ /^      \},/) {
				last;
			}
		}
	}
}
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
		&Log(sprintf("[E] result \$![%d] \$?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	} else {
		&Log(sprintf("[D] result \$![%d] \$?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
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
