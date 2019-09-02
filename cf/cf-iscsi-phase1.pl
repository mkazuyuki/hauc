#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');		# ESXi IP address
my @esxi_pw	= ('NEC123nec!', 'NEC123nec!');			# ESXi root password
# my @iscsi_ip1	= ('172.31.255.11', '172.31.255.12');		# iSCSI IP address
# my @iscsi_ip2	= ('172.31.253.11', '172.31.253.12');		# iSCSI IP address
# my @iscsi_ip3	= ('172.31.254.11', '172.31.254.12');		# iSCSI IP address
# my @iscsi_vname	= ('iSCSI1', 'iSCSI2');				# iSCSI VM Name
# my @iscsi_pw	= ('NEC123nec!', 'NEC123nec!');			# iSCSI root password
# my @dsname	= ('iSCSI1');
######
######
######
my $DATASTORE_SIZE = "500G";
######
######
######
#-------------------------------------------------------------------------------

# Globals
my @lines	= ();

# Main
#-------------------------------------------------------------------------------

for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip1[$i] ";
	&execution($cmd . "-m ESXi-scripts\cf-iscsi-" . ($i + 1) .".sh");
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
