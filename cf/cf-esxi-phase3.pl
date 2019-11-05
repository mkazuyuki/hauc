#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;		# ESXi IP address
our @esxi_pw;		# ESXi root password
our @esxi_iqn;
our $iscsi_fip;
require "./hauc.conf";

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();
my $iscsi_addr	= $iscsi_fip . ":3260";	# IP Addresss:Port for iSCSI Target

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

	&execution(".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] -m ESXi-scripts/cf-esxi-1" . ($i+1) . ".sh");
}

# Validation
for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";
	&execution("$cmd \"esxcli iscsi adapter discovery sendtarget list\"");
	my $found = 0;
	foreach (@lines) {
		if (/vmhba.*${iscsi_fip}/) {
			$found = 1;
		}
	}
	if (!$found){
		&Log("[E] *******************************************************\n");
		&Log("[E] On ESXi#" . ($i+1) . ", iSCSI Target not configured.\n");
		&Log("[E] Check your configuration.\n");
		&Log("[E] Push return key\n");
		&Log("[E] *******************************************************\n");
		my $tmp = <STDIN>;
		exit;
	}
}
&Log("[I] ******************************************\n");
&Log("[I] Both ESXi were connected to iSCSI Target.\n");
&Log("[I] This phase was successfully completed.\n");
&Log("[I] Push return key\n");
&Log("[I] ******************************************\n");
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

	open(LOG, ">> phase3.log");
	print LOG "$date $_[0]";
	close(LOG);

	return 0;
}
