#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');		# ESXi IP address
my @esxi_pw	= ('NEC123nec!', 'NEC123nec!');			# ESXi root password
my @iscsi_ip1	= ('172.31.255.11', '172.31.255.12');		# iSCSI IP address
my @iscsi_ip2	= ('172.31.253.11', '172.31.253.12');		# iSCSI IP address
my @iscsi_ip3	= ('172.31.254.11', '172.31.254.12');		# iSCSI IP address
my @iscsi_vname	= ('iSCSI1', 'iSCSI2');				# iSCSI VM Name
my @iscsi_pw	= ('NEC123nec!', 'NEC123nec!');			# iSCSI root password
my @dsname	= ('iSCSI1');
#-------------------------------------------------------------------------------

# Globals
my $devid	= 3000;	# CDROM Device ID of the VM. It can be obtained by "vim-cmd vmsvc/device.getdevices $VMID".
my @lines	= ();

# Main
#-------------------------------------------------------------------------------
# Connecting DVD Drive to the VMs
#&connectDVD;

for my $i (0..1) {
	&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] expresscls-4.1.1-1.x86_64.rpm $iscsi_ip1[$i]:/root/");
	&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] ECX4.x-lin1.key $iscsi_ip1[$i]:/root/");
	&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] ECX4.x-Rep-lin1.key $iscsi_ip1[$i]:/root/");
	&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] ECX4.x-Rep-lin2.key $iscsi_ip1[$i]:/root/");

	my $cmd = ".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[$i] $iscsi_ip1[$i] ";
	&execution($cmd . "\"mkdir /media/cdrom; mount /dev/cdrom /media/cdrom\"");
	&execution($cmd . "\"yum --disablerepo=* --enablerepo=c7-media install -y targetcli targetd perl\"");
	&execution($cmd . "\"hostnamectl set-hostname iscsi1; systemctl stop firewalld.service; systemctl disable firewalld.service\"");
	&execution($cmd . "\"sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config\"");
	&execution($cmd . "\"yes no | ssh-keygen -t rsa -f /root/.ssh/id_rsa -N \\\"\\\"\"");
	&execution($cmd . "\"umount /media/cdrom\"");

	#&execution($cmd . "\"nmcli c m ens192 ipv4.method manual ipv4.addresses $iscsi_ip1[$i] connection.autoconnect yes\"");
	&execution($cmd . "\"nmcli c m ens224 ipv4.method manual ipv4.addresses $iscsi_ip2[$i] connection.autoconnect yes\"");
	&execution($cmd . "\"nmcli c m ens256 ipv4.method manual ipv4.addresses $iscsi_ip3[$i] connection.autoconnect yes\"");
	&execution($cmd . "\"yes | parted /dev/sdb mklabel msdos mkpart primary 1MiB 1025MiB mkpart primary 1025MiB 100%\"");
	&execution($cmd . "\"rpm -ivh /root/expresscls*.rpm\"");
	&execution($cmd . "\"clplcnsc -i ECX4.x-lin1.key\"");
	&execution($cmd . "\"clplcnsc -i ECX4.x-Rep-lin" . ( $i + 1) . ".key\"");

	#reboot

	# Disconnecting CDROM Drive
	#my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] \"perl VMID=`vim-cmd vmsvc/getallvms | grep \\\" $vmname \\\" | awk '{print \\\$1}'`; vim-cmd vmsvc/device.connection \$VMID $devid true\"";
}

#.\plink.exe -no-antispoof -l root -pw NEC123nec! 172.31.255.3 "VMNAME=iSCSI1;DEVID=3000;VMID=`vim-cmd vmsvc/getallvms | grep \" ${VMNAME} \" | awk '{print $1}'`; vim-cmd vmsvc/device.connection $VMID $DEVID false"  

#-------------------------------------------------------------------------------
sub connectDVD {
	for my $i (0..1) {
		my $cmd0 = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] ";
		my $cmd = $cmd0 . "\"VMID=`vim-cmd vmsvc/getallvms | grep \\\" $iscsi_vname[$i] \\\" | awk '{print \$1}'`; vim-cmd vmsvc/device.getdevices \$VMID\"";
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
				$cmd = $cmd0 . "\"VMID=`vim-cmd vmsvc/getallvms | grep \\\" $iscsi_vname[$i] \\\" | awk '{print \\\$1}'`; vim-cmd vmsvc/device.connection \$VMID $devid true\"";
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
