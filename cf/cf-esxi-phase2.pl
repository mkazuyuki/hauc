#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');	# ESXi IP address
my @esxi_pw	= ('NEC123nec!', 'NEC123nec!');		# ESXi root password

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();

# Main
#-------------------------------------------------------------------------------
for my $i (0..1) {
	&execution(".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] -m ESXi-scripts/cf-esxi-1" . ($i+1) . ".sh");
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
