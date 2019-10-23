#!perl.exe
use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our @esxi_isa_ip;
our @esxi_isa_nm;
require "./hauc.conf";

# Global variable
#-------------------------------------------------------------------------------
my @lines	= ();

# vSwitch
my @vswitch = ("vSwitch", "Mirror_vswitch", "iSCSI_vswitch", "uc_vm_vswitch");

my %portgroup = (
	'vSwitch' => [ 'VM Network', 'Management Networ'],
	'Mirror_vswitch' => ['Mirror_portgroup'],
	'iSCSI_vswitch' => ['iSCSI_portgroup', 'iSCSI_Initiator'],
	'uc_vm_vswitch' => ['uc_vm_portgroup']
);

my %uplink;
$uplink{"vSwitch"} = "vmnic0";
$uplink{"Mirror_vswitch"} = "vmnic1";
$uplink{"iSCSI_vswitch"} = "vmnic2";
$uplink{"uc_vm_vswitch"} = "vmnic3";

# Main
#-------------------------------------------------------------------------------

for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] ";
	&execution("$cmd esxcfg-vswitch -L vmnic1 Mirror_vswitch");
	&execution("$cmd esxcfg-vswitch -L vmnic2 iSCSI_vswitch");
	&execution("$cmd esxcfg-vswitch -L vmnic3 uc_vm_vswitch");
	&execution("$cmd esxcfg-vswitch -A Mirror_portgroup Mirror_vswitch");
	&execution("$cmd esxcfg-vswitch -A iSCSI_portgroup iSCSI_vswitch");
	&execution("$cmd esxcfg-vswitch -A iSCSI_Initiator iSCSI_vswitch");
	&execution("$cmd esxcfg-vswitch -A uc_vm_portgroup uc_vm_vswitch");
	&execution("$cmd esxcfg-vmknic -a -i ${esxi_isa_ip[$i]} -n ${esxi_isa_nm[$i]} iSCSI_Initiator");
	&execution("$cmd /etc/init.d/hostd restart");
}

# Validation
for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] ";
	&execution("$cmd esxcfg-vswitch -l");
	foreach my $vs (@vswitch) {
		foreach my $pg (@{$portgroup{$vs}}) {
			# print "[$vs][$pg]\n";
			my $found = 0;
			my $s;	# Start, End, (line) Number
			my $e;
			my $n;
			for ($s=0; $s<@lines; $s++) {
				# print "[s $s] $lines[$s]\n";
				if ($lines[$s] =~ /${vs}.*${uplink{$vs}}/){
					# print "[!][$vs $&]\n";
					last
				}
			}
			for ($e=$s+1; $e<@lines; $e++) {
				# print "[e $e] $lines[$e]\n";
				if ($lines[$e] =~ /Switch Name/){
					last
				}
			}
			for ($n=$s+1; $n<$e; $n++){
				# print "[n $n] $lines[$n]\n";
				if ($lines[$n] =~ /$pg/) {
					$found = 1;
					last;
				}
			}
			if (!$found) {
				&Log("[E] *******************************************************\n");
				&Log("[E] On ESXi#" . ($i+1) . ", Portgroup [$pg] was not found in vSwitch [$vs].\n");
				&Log("[E] Check your configuration.\n");
				&Log("[E] Push return key\n");
				&Log("[E] *******************************************************\n");
				my $tmp = <STDIN>;
				exit;
			} else {
				&Log("[I] on [ESXi#" . ($i+1) . ", Portgroup [$pg] was found in vSwitch [$vs].\n");
			}
		}
	}
}
&Log("[I] ******************************************\n");
&Log("[I] All Portgroup were found in right vSwitch.\n");
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

	open(LOG, ">> phase1.log");
	print LOG "$date $_[0]";
	close(LOG);

	return 0;
}
