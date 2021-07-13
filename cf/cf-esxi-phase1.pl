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
my @vswitch = ("vSwitch0", "Mirror_vswitch", "iSCSI_vswitch", "uc_vm_vswitch");

my %portgroup = (
	'vSwitch' => [ 'VM Network', 'Management Network'],
	'Mirror_vswitch' => ['Mirror_portgroup'],
	'iSCSI_vswitch' => ['iSCSI_portgroup', 'iSCSI_Initiator'],
	'uc_vm_vswitch' => ['uc_vm_portgroup']
);

my %uplink;
$uplink{"vSwitch0"} = "vmnic0";
$uplink{"Mirror_vswitch"} = "vmnic1";
$uplink{"iSCSI_vswitch"} = "vmnic2";
$uplink{"uc_vm_vswitch"} = "vmnic3";

# Main
#-------------------------------------------------------------------------------

# Pre message
&Log("
When you see the WARNING like following, answer \"y\".

  2019/12/10 23:44:49 [D] | WARNING - POTENTIAL SECURITY BREACH!
  2019/12/10 23:44:49 [D] | The server's host key does not match the one PuTTY has
  2019/12/10 23:44:49 [D] | cached in the registry. This means that either the
  2019/12/10 23:44:49 [D] | server administrator has changed the host key, or you
  2019/12/10 23:44:49 [D] | have actually connected to another computer pretending
  2019/12/10 23:44:49 [D] | to be the server.
  2019/12/10 23:44:49 [D] | The new rsa2 key fingerprint is:
  2019/12/10 23:44:49 [D] | ssh-rsa 2048 2f:7a:f6:f7:85:d5:fc:f4:f0:c5:9b:a2:59:19:46:60
  2019/12/10 23:44:49 [D] | If you were expecting this change and trust the new key,
  2019/12/10 23:44:49 [D] | enter \"y\" to update PuTTY's cache and continue connecting.
  2019/12/10 23:44:49 [D] | If you want to carry on connecting but without updating
  2019/12/10 23:44:49 [D] | the cache, enter "n".
  2019/12/10 23:44:49 [D] | If you want to abandon the connection completely, press
  2019/12/10 23:44:49 [D] | Return to cancel. Pressing Return is the ONLY guaranteed
  2019/12/10 23:44:49 [D] | safe choice.
  2019/12/10 23:44:57 [D] | Update cached key? (y/n, Return cancels connection) Connection abandoned.

Push return key
");
my $tmp = <STDIN>;

for my $i (0..1) {
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";
	&execution("$cmd esxcfg-vswitch -a Mirror_vswitch");
	&execution("$cmd esxcfg-vswitch -a iSCSI_vswitch");
	&execution("$cmd esxcfg-vswitch -a uc_vm_vswitch");
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
	my $cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esxi_pw[$i]\" $esxi_ip[$i] ";
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
