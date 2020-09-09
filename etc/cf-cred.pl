#!perl.exe

use strict;
use warnings;

use File::Basename;

my $bn = basename($0, '');

my @esx_ip = ();
my @vma_ip = ();
my @esx_pw = ();
my @vma_pw = ();
my @outs;
my $cmd;

$esx_ip[0] = shift || "";
$esx_pw[0] = shift || "";
$esx_ip[1] = shift || "";
$esx_pw[1] = shift || "";
$vma_ip[0] = shift || "";
$vma_pw[0] = shift || "";
$vma_ip[1] = shift || "";
$vma_pw[1] = shift || "";

for my $i (0..1) {
	if (	($esx_ip[$i] eq "") ||
		($vma_ip[$i] eq "") ||
		($esx_pw[$i] eq "") ||
		($vma_pw[$i] eq ""))
	{
		&usage;
		exit 1;
	}
}

&Log("[I] ESXi 1 IP = $esx_ip[0]\n");
&Log("[I] ESXi 1 PW = $esx_pw[0]\n");
&Log("[I] ESXi 2 IP = $esx_ip[1]\n");
&Log("[I] ESXi 2 PW = $esx_pw[1]\n");
&Log("[I] vMA  1 IP = $vma_ip[0]\n");
&Log("[I] vMA  1 PW = $vma_pw[0]\n");
&Log("[I] vMA  2 IP = $vma_ip[1]\n");
&Log("[I] vMA  2 PW = $vma_pw[1]\n");

## Checking ssh accessibility
for my $i (0..1) {
	&execution ("echo y | .\\plink.exe -l root -pw \"$esx_pw[$i]\" $esx_ip[$i] esxcli --version");
	if ($? != 0 ){ exit 1 }
	&execution ("echo y | .\\plink.exe -l root -pw \"$vma_pw[$i]\" $vma_ip[$i] esxcli --version");
	if ($? != 0 ){ exit 1 }
}

&Log("[D] ----------\n");
&Log("[I] #### SSH ####\n");

# i is index for ESXi
for my $i (0..1) {
	# j is index for vMA
	for my $j (0..1) {
		$cmd = ".\\plink.exe -no-antispoof -l root -pw \"$vma_pw[$j]\" $vma_ip[$j] ";
		&execution ($cmd . "/usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s $esx_ip[$i] -u root -p $esx_pw[$i]");
		&execution ($cmd . "esxcli -s $esx_ip[$i] system version get");
		foreach(@outs){
			if (/thumbprint: (.*) \(/){
				&execution ($cmd . "/usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s $esx_ip[$i] -t $1");
				last;
			}
		}
		
		# configuring known_hosts
		&execution($cmd . "ssh-keygen -R $esx_ip[$i]");
		&execution($cmd . "\"ssh-keyscan $esx_ip[$i] >> ~/.ssh/known_hosts\"");

		# configuring ssh keys
		&execution(".\\pscp.exe -l root -pw \"$vma_pw[$j]\" $vma_ip[$j]:/root/.ssh/id_rsa.pub .\\id_rsa.pub");
		&execution(".\\pscp.exe -l root -pw \"$esx_pw[$i]\" .\\id_rsa.pub $esx_ip[$i]:/tmp");

		$cmd = ".\\plink.exe -no-antispoof -l root -pw \"$esx_pw[$i]\" $esx_ip[$i] ";
		&execution("$cmd \"a=`cat /tmp/id_rsa.pub`; grep \\\"\$a\\\" /etc/ssh/keys-root/authorized_keys\"");
		if ($?) {
			# create entry for vMA host in authorized_keys in ESXi when authorized_keys not exists or it does not have the entry for vMA host.
			&execution("$cmd \"cat /tmp/id_rsa.pub >> /etc/ssh/keys-root/authorized_keys\"");
		}
		&execution("$cmd \"rm /tmp/id_rsa.pub\"");
		&execution("del id_rsa.pub");
	}
}

# Displaying entries in the credential store
&Log("[I] #### RESULT ####\n");
for my $i (0..1) {
	my $cmd = "/usr/lib/vmware-vcli/apps/general/credstore_admin.pl list";
	&execution (".\\plink.exe -no-antispoof -l root -pw \"$vma_pw[$i]\" $vma_ip[$i] $cmd");
}

#-------------------------------------------------------------------------------
sub usage {
	print "
	Usage:

	$bn ESXi1_IP ESXi1_PW ESXi2_IP ESXi2_PW vMA1_IP vMA1_PW vMA2_IP vMA2_PW
	
	ESXi1_IP	IP   address  of first  ESXi host
	ESXi1_PW	root password of first  ESXi host
	ESXi2_IP	IP   address  of second ESXi host
	ESXi2_PS	root password of second ESXi host
	vMA1_IP 	IP   address  of first  vMA VM
	vMA1_PW 	root password of first  vMA VM
	vMA2_IP 	IP   address  of second vMA VM
	vMA2_PW 	root password of second vMA VM
	
	";
}
#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	@outs = ();
	&Log("[D]	executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	while(<$h>){
		if (/Keyboard-interactive authentication prompts from server:/) { next; }
		elsif (/End of keyboard-interactive prompts from server/) { next; }
		chomp;
		&Log("[D]	| $_\n");
		push (@outs, $_);
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

	open(LOG, ">> cf-cred.log");
	print LOG "$date $_[0]";
	close(LOG);

	return 0;
}
