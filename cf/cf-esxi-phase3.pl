#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;		# ESXi IP address
our @esxi_pw;		# ESXi root password
our @esxi_iqn;
our $iscsi_addr;	# IP Addresss:Port for iSCSI Target
require "./hauc.conf";

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();

# Main
#-------------------------------------------------------------------------------
for my $i (0..1) {
	open(IN,  "ESXi-scripts/cf-esxi-1" . ($i+1) . ".sh");
	open(OUT, "> ESXi-scripts/cf-esxi-1" . ($i+1) . ".txt");
	while (<IN>) {
		s/^ADDR=.*/ADDR='${iscsi_addr}'/;
		s/^IQN=.*/IQN='${esxi_iqn[$i]}'/;
		print OUT;
	}
	close (OUT);
	close (IN);
	system("move ESXi-scripts\\cf-esxi-1" . ($i+1) . ".txt ESXi-scripts\\cf-esxi-1" . ($i+1) . ".sh");

	#&execution(".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] -m ESXi-scripts/cf-esxi-1" . ($i+1) . ".sh");
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
