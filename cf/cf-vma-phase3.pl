#!/usr/bin/perl -w

#
# This script creates ECX configuration files (clp.conf and scripts)
# and configurs password free access from iSCSI and vMA hosts to ESXi hosts
# 
# Prerequisite package
#
#	plink.exe , pscp.exe
#		https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
#			https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe
#			https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe

use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our @vma_ip;
our @vma_pw;
our @iscsi_ip;
our @iscsi_pw;
our $dsname;
our $vsw;
require "./hauc.conf" or die "file not found hauc.pl";
#-------------------------------------------------------------------------------

# Global variables
#-------------------------------------------------------------------------------
my @wwn 	= ('iqn.1998-01.com.vmware:1', 'iqn.1998-01.com.vmware:2');	# Pre-defined iSCSI WWN to be set to ESXi
my @vmhba	= ('', '');							# iSCSI Software Adapter
my @vma_hn	= ('', '');							# vMA hostname
my @vma_dn	= ('', '');							# vMA Display Name

my @vmx = ();		# Array of Hash of VMs for an ESXi
my @menu_vMA;
my $ret = "";
my @outs = ();

my $CFG_DIR	= "conf/";
my $CFG_FILE	= $CFG_DIR . "clp.conf";
my $SCRIPT_DIR	= "script";
my $TMPL_DIR	= "template/vMA/";
my $TMPL_CONF	= $TMPL_DIR . "clp.conf";
my $TMPL_START	= $TMPL_DIR . "vm-start.pl";
my $TMPL_STOP	= $TMPL_DIR . "vm-stop.pl";
my $TMPL_MON	= $TMPL_DIR . "genw-vm.pl";

open(IN, $TMPL_CONF);
my @lines = <IN>;
close(IN);

while ( 1 ) {
	if ( ! &select ( &menu ) ) {exit}
}

exit;

#
# subroutines
#-------------------------------------------------------------------------------
sub menu {
	@menu_vMA = (
		'save and exit',
		'set ESXi#1 IP            : ' . $esxi_ip[0],
		'set ESXi#2 IP            : ' . $esxi_ip[1],
		'set ESXi#1 root password : ' . $esxi_pw[0],
		'set ESXi#2 root password : ' . $esxi_pw[1],
		'set vMA#1 IP             : ' . $vma_ip[0],
		'set vMA#2 IP             : ' . $vma_ip[1],
		'set vMA#1 root password  : ' . $vma_pw[0],
		'set vMA#2 root password  : ' . $vma_pw[1],
		'set iSCSI#1 IP           : ' . $iscsi_ip[0],
		'set iSCSI#2 IP           : ' . $iscsi_ip[1],
		'set iSCSI#1 root password: ' . $iscsi_pw[0],
		'set iSCSI#2 root password: ' . $iscsi_pw[1],
		'set iSCSI Datastore name : ' . $dsname,
		'set vSwitch name         : ' . $vsw,
		'add VM',
		'del VM',
		'show VM'
	);
	my $i = 0;
	print "\n--------\n";
	foreach (@menu_vMA) {
		print "[" . ($i++) . "] $_\n";  
	}
	print "\n(0.." . ($i - 1) . ") > ";

	$ret = <STDIN>;
	chomp $ret;
	return $ret;
}

sub select {
	my $i = shift;
	if ($i !~ /^\d+$/){
		print "invalid (should be numeric)\n";
		return -1;
	}
	elsif ( $menu_vMA[$i] =~ /save and exit/ ) {
		&Save;
		print "\nThe configuration has applied (the same has saved in the \"conf\" directry).\nBye.\n";
		return 0;
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1..2]) IP/ ) {
		&setESXiIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1,2]) root password/ ) {
		&setESXiPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1,2]) IP/ ) {
		&setvMAIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1..2]) root password/ ) {
		&setvMAPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI#([1,2]) IP/ ) {
		&setiSCSIIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI#([1..2]) root password/ ) {
		&setiSCSIPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI Datastore name/ ) {
		&setDatastoreName;
	}
	elsif ( $menu_vMA[$i] =~ /set vSwitch name/ ) {
		&setvSwitch($1);
	}
	elsif ( $menu_vMA[$i] =~ /add VM/ ) {
		&addVM;
	}
	elsif ( $menu_vMA[$i] =~ /del VM/ ) {
		&delVM;
	}
	elsif ( $menu_vMA[$i] =~ /show VM/ ) {
		&showVM;
	}
	else {
		print "[$i] Invalid.\n";
	}
	return $i;
}

#
# Changing clp.conf contents for adding new VM group resource
#-------
sub AddNode {
	my $esxidx = shift;
	my $vmname = shift;
	my $i = 0;
	my $gid = 0;
	my $fop = "";

	#print "[D] esxidx[$esxidx] vmname[$vmname]\n";

	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<gid>(.*)<\/gid>/){
			$gid = $1 + 1;
			last;
		}
	}

	#
	# Failover Policy
	#
	if ($esxidx == 1) {
		$fop =	"		<policy name=\"$vma_hn[1]\"><order>0</order></policy>\n".
			"		<policy name=\"$vma_hn[0]\"><order>1</order></policy>\n";
	}

	#
	# Group
	#
	my @ins = (
		"	<group name=\"failover-$vmname\">\n",
		"		<comment> <\/comment>\n",
		"		<resource name=\"exec\@exec-$vmname\"/>\n",
		"		<gid>$gid</gid>\n",
		$fop,
		"	</group>\n"
	);
	splice(@lines, $#lines, 0, @ins);

	#
	# Resource
	#
	@ins = (
		"		<exec name=\"exec-$vmname\">",
		"			<comment> </comment>",
		"			<parameters>",
		"				<act><path>start.sh</path></act>",
		"				<deact><path>stop.sh</path></deact>",
		"				<userlog>/opt/nec/clusterpro/log/exec-$vmname.log</userlog>",
		"				<logrotate><use>1</use></logrotate>",
		"			</parameters>",
		"			<act><retry>2</retry></act>\n",
		"			<deact>\n",
		"				<action>5</action>\n",
		"				<retry>1</retry>\n",
		"			</deact>\n",
		"		</exec>\n"
	);
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<\/resource>/){
			last;
		}
	}
	splice(@lines, $i, 0, @ins);

	#
	# Monitor
	#
	@ins = (
		"	<genw name=\"genw-$vmname\">\n",
		"		<comment> </comment>\n",
		"		<target>exec-$vmname</target>\n",		##
		"		<parameters>\n",
		"			<path>genw.sh</path>\n",
		"			<userlog>/opt/nec/clusterpro/log/genw-$vmname.log</userlog>\n",		##
		"			<logrotate>\n",
		"				<use>1</use>\n",
		"			</logrotate>\n",
		"		</parameters>\n",
		"		<polling>\n",
		"			<timing>1</timing>\n",
		"			<reconfirmation>1</reconfirmation>\n",
		"		</polling>\n",
		"		<relation>\n",
		"			<name>failover-$vmname</name>\n",	##
		"			<type>grp</type>\n",
		"		</relation>\n",
		"		<emergency>\n",
		"			<threshold>\n",
		"				<restart>0</restart>\n",
		"			</threshold>\n",
		"		</emergency>\n",
		"	</genw>\n"
	);
	for($i = $#lines; $i > 0; $i--){
		if (($lines[$i] =~ /<\/genw>/) || ($lines[$i] =~ /<types name=\"genw\"\/>/)){
			last;
		}
	}
	splice(@lines, $i +1, 0, @ins);

	#
	# Object number
	#
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<objectnumber>(.*)<\/objectnumber>/){
			$lines[$i] = "<objectnumber>" .  ($1 + 3) . "</objectnumber>";
			last;
		}
	}
}

sub DelNode {
	my $esxidx = shift;
	my $vmname = shift;
	my $i = 0;
	my $j = 0;
	my $gid = 0;

	print "[D] deleting [$vmx[$esxidx]{$vmname}]\n";
	delete($vmx[$esxidx]{$vmname});

	#
	# Group
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<group name=\"failover-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/group>/) {
			last;
		}
	}
	my @deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# Resource
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<exec name=\"exec-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/exec>/) {
			last;
		}
	}
	@deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# Monitor
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<genw name=\"genw-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/genw>/) {
			last;
		}
	}
	@deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# GID
	# Object Number
	#
	foreach (@lines) {
		if (/<gid>(.*)<\/gid>/) {
			s/$1/$gid/;
			$gid++;
		}
		if(/<objectnumber>(.*)<\/objectnumber>/){
			my $objnum = $1 - 3;
			s/$1/$objnum/;
		}
	}
}


#
# Get hostname of vMA hosts
# 	Setting up @vma_hn
#
sub getvMAHostname {
	# Check vMA nodes connectable and get hostname
	if (( $vma_hn[0] eq '' ) || ( $vma_hn[1] eq '' )) {
		&Log("[I] Getting hostname of vMA\n");
		&Log("[D] -----------\n");
		for my $i (0 .. 1) {
			if (&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[$i] $vma_ip[$i] hostname")) {
				&Log("[E] failed to access vMA#" . ($i+1) .". Check IP or password.\n");
				return -1;
			} else {
				$vma_hn[$i] = shift @outs;
				&Log("[I] vMA#" . ($i+1) . " hostname = [$vma_hn[$i]]\n");
			}
		}
		&Log("[D] -----------\n");
	}
	return 0;
}

#
# Get Display Name of vMA hosts
# 	Setting up @vma_dn
#
sub getvMADisplayName{
	for (my $i = 0; $i < 2; $i++) {
		my $found = 0;
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i]";

		&Log("[D] ----------\n");
		&Log("[D] Getting VM <ID> and <Display Name>\n");
		&Log("[D] ----------\n");
		&execution("$cmd vim-cmd vmsvc/getallvms");
		my %vmname = ();
		foreach (@outs) {
			if (/^(\d*)\s*(.*\S)\s*\[/){
				$vmname{$1} = $2;
			}
		}
		foreach my $id (keys %vmname) {
			#if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep 'ipAddress = \\\"$vma_ip[$i]\\\"'\"")) {
			if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep '$vma_ip[$i]'\"")) {
				$found = 1;
				$vma_dn[$i] = $vmname{$id};
				&Log("[D] ----------\n");
				&Log("[D] Found vMA Display Name [$vma_dn[$i]] for ESXi #[$i]\n");
				&Log("[D] ----------\n");
				last;
			}
		}
		if ($found == 0) {
			die "[E] No vMA found\n";
		}
	}
}

sub setIQN {
	for (my $i = 0; $i < 2; $i++) {
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i]";

		# Getting vmhba
		&execution("$cmd \"esxcli iscsi adapter list\"");
		foreach ( @outs ) {
			if ( /^vmhba[\S]+/ ) {
				$vmhba[$i] = $&;
			}
		}
		&Log("[I] ----------\n");
		&Log("[I] iSCSI Sofware Adapter HBA#" . ($i +1) . " = [" . $vmhba[$i] . "]\n");
		&Log("[I] ----------\n");

		# Checking WWN before setting it
		&execution ("$cmd esxcli iscsi adapter get -A $vmhba[$i]");
		foreach ( @outs ) {
			if ( /^   Name: (.+)/ ) {
				&Log("[I] ----------\n");
				&Log("[I] Before setting WWN#" . ($i +1) . " = [$1]\n");
				&Log("[I] ----------\n");
			}
		}

		# Setting WWN
		&execution ("$cmd esxcli iscsi adapter set -A $vmhba[$i] -n $wwn[$i]");

		# Checking WWN after setting it
		&execution ("$cmd esxcli iscsi adapter get -A $vmhba[$i]");
		foreach ( @outs ) {
			if ( /^   Name: (.+)/ ) {
				&Log("[I] ----------\n");
				&Log("[I] After setting  WWN#" . ($i +1) . " = [$1]\n");
				&Log("[I] ----------\n");
			}
		}
	}
}


#
# Setup before.local and after.local on vMA hosts
#
sub putInitScripts {
	my @locals = ("before.local", "after.local");
	for (my $n = 0; $n < 2; $n++) {
		foreach my $file (@locals) {
			open(IN, $TMPL_DIR . $file) or die;
			open(OUT,">  $file") or die;
			#binmode(IN);
			binmode(OUT);
			while (<IN>) {
				if (/%%VMK%%/)		{ s/$&/$esxi_ip[$n]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				print OUT;
			}
			close(OUT);
			close(IN);
			&execution(".\\pscp.exe -l root -pw $vma_pw[$n] $file $vma_ip[$n]:/tmp");
			unlink ( "$file" ) or die;
		}

		my $file = "vma-init-files.sh";
		open(IN, "$SCRIPT_DIR/$file") or die;
		open(OUT,">  $file") or die;
		while (<IN>) {
			if (/%%VMAPW%%/)	{ s/$&/$vma_pw[$n]/;}
			print OUT;
		}
		close(OUT);
		close(IN);
		&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[$n] $vma_ip[$n] -m $file");
		unlink ( "$file" ) or die;
	}
}

sub Save {
	&Log("[I] Check ESXi, iSCSI nodes connectable\n");
	for (my $i = 0; $i < 2; $i++) {
		if (&execution(".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] hostname")) {
			&Log("[E] failed to access ESXi#" . ($i+1) .". Check IP or password.\n");
			return -1;
		}
		if (&execution(".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] hostname")) {
			&Log("[E] failed to access iscsi#" . ($i+1) .". Check IP or password.\n");
			return -1;
		}
		# checking vMA node connectivity was done at addVM()
		&getvMAHostname;
	}

	#
	# Setup ESXi for
	# - auto start of iSCSI VMs and vMA VMs
	# - suppressing shell warning on ESX Host Client
	# 
	for my $i (0 .. 1) {
		my $found = 0;
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i]";
		&Log("[D] ----------\n");
		&Log("[D] Configuring ESXi : auto start iSCSI and vMA VMs\n");
		&Log("[D] Configuring ESXi : suppressing shell warning on ESX Host Client\n");
		&Log("[D] ----------\n");
		&execution("$cmd vim-cmd vmsvc/getallvms");
		my $vmid_vma;
		my $vmid_iscsi;
		my %vmname = ();
		foreach (@outs) {
			if (/^(\d*)\s*(.*\S)\s*\[/){
				$vmname{$1} = $2;
			}
		}
		foreach my $id (keys %vmname) {
			#if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep 'ipAddress = \\\"$vma_ip[$i]\\\"'\"")) {
			if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep '$vma_ip[$i]'\"")) {
				$vmid_vma = $id;
				&Log("[D] ----------\n");
				&Log("[D] Found vMA VM ID[$id] for ESXi #[$i]\n");
				&Log("[D] ----------\n");
				$found++;
			}
			#if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep 'ipAddress = \\\"$iscsi_ip[$i]\\\"'\"")) {
			if (! &execution("$cmd \"vim-cmd vmsvc/get.guest $id | grep '$iscsi_ip[$i]'\"")) {
				$vmid_iscsi = $id;
				&Log("[D] ----------\n");
				&Log("[D] Found iSCSI VM ID[$id] for ESXi #[$i]\n");
				&Log("[D] ----------\n");
				$found++;
			}
			if ($found == 2) {last}
		}
		if ($found != 2) {
			die "[E] vMA or iSCSI VM not found on ESXi #[$i]\n";
		}
		&execution("$cmd vim-cmd hostsvc/autostartmanager/enable_autostart true");
		&execution("$cmd vim-cmd hostsvc/autostartmanager/update_autostartentry $vmid_iscsi powerOn 120 1 guestShutdown 120 yes");
		&execution("$cmd vim-cmd hostsvc/autostartmanager/update_autostartentry $vmid_vma   powerOn 120 2 guestShutdown 120 yes");
		&execution("$cmd esxcli system settings advanced set -i 1 -o /UserVars/SuppressShellWarning");
	}

	# Setup before.local and after.local on vMA hosts
	&putInitScripts;

	# Setup iSCSI Initiator IQN
	&setIQN;

	# Setup Authentication

	# Setup SSH Hostkey of ESXi and iSCSI on vMA VMs
	for my $i (0 .. 1) {

		# Setup SSH Hostkey of iSCSI on vMA VMs
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $vma_pw[$i] $vma_ip[$i]";
		&execution("$cmd ssh-keygen -R $iscsi_ip[$i]");
		&execution("$cmd \"ssh-keyscan -t rsa $iscsi_ip[$i] >> ~/.ssh/known_hosts\"");

		# Setup SSH Hostkey of ESXi on vMA VMs
		for my $j (0..1) {
			&execution("$cmd ssh-keygen -R $esxi_ip[$j]");
			&execution("$cmd \"ssh-keyscan $esxi_ip[$j] >> ~/.ssh/known_hosts\"");
		}

		# Setup SSH Hostkey of ESXi on iSCSI VMs
		$cmd = ".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[$i] $iscsi_ip[$i]";
		for my $j (0..1) {
			&execution("$cmd ssh-keygen -R $esxi_ip[$j]");
			&execution("$cmd \"ssh-keyscan $esxi_ip[$j] >> ~/.ssh/known_hosts\"");
		}
	}

	# Setup vMA, iSCSI ssh public key on ESXi
	for my $i (0..1) {

		# Get vMA, iSCSI ssh public key
		&execution(".\\pscp.exe -l root -pw $vma_pw[$i] $vma_ip[$i]:/root/.ssh/id_rsa.pub .\\id_rsa_vma_$i.pub");
		&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i]:/root/.ssh/id_rsa.pub .\\id_rsa_iscsi_$i.pub");

		# Put vMA, iSCSI ssh public key on ESXi
		for my $j (0..1) {
			&execution(".\\pscp.exe -l root -pw $esxi_pw[$j] .\\id_rsa_vma_$i.pub   $esxi_ip[$j]:/tmp");
			&execution(".\\pscp.exe -l root -pw $esxi_pw[$j] .\\id_rsa_iscsi_$i.pub $esxi_ip[$j]:/tmp");
		}

		# Put vMA ssh public key on iSCSI, and make /root/.ssh/authorized_keys
		&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] .\\id_rsa_vma_$i.pub $iscsi_ip[$i]:/tmp");
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $iscsi_pw[$i] $iscsi_ip[$i]";
		&execution("$cmd \"a=`cat /tmp/id_rsa_vma_$i.pub`; grep \\\"\$a\\\" ~/.ssh/authorized_keys\"");
		if ($?) {
			# create entry for vMA in authorized_keys in iSCSI when authorized_keys not exists or it does not have the entry for vMA node.
			&execution("$cmd \"cat /tmp/id_rsa_vma_$i.pub >> ~/.ssh/authorized_keys\"");
		}
		&execution("$cmd \"rm /tmp/id_rsa_vma_$i.pub\"");

		&execution("del id_rsa_vma_$i.pub id_rsa_iscsi_$i.pub");
	}

	# Setup ESXi
	for my $i (0..1) {
		my $cmd = ".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] ";
		# Make /etc/ssh/keys-root/authorized_keys on ESXi
		for my $j (0..1) {
			&execution($cmd . "sed -i -e '/root\@vma"   . ($j+1) . "\$/d' /etc/ssh/keys-root/authorized_keys");
			&execution($cmd . "sed -i -e '/root\@iscsi" . ($j+1) . "\$/d' /etc/ssh/keys-root/authorized_keys");
			&execution($cmd . "\"cat /tmp/id_rsa_vma_$j.pub   >> /etc/ssh/keys-root/authorized_keys\"");
			&execution($cmd . "\"cat /tmp/id_rsa_iscsi_$j.pub >> /etc/ssh/keys-root/authorized_keys\"");
			&execution($cmd . "rm /tmp/id_rsa_vma_$j.pub /tmp/id_rsa_iscsi_$j.pub");
		}
		# Disable ATS Heartbeat
		&execution ($cmd . "esxcli system settings advanced set -i 0 -o /VMFS3/UseATSForHBOnVMFS5");
		&execution ($cmd . "esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5");
	}

	#
	# Making directry for Group and Monitor resource
	#
	my @DIR = ();
	push @DIR, $CFG_DIR;
	push @DIR, $CFG_DIR . "scripts";
	push @DIR, $CFG_DIR . "scripts/monitor.s";
	foreach (@lines){
		if (/<group name=\"failover-(.*)\">/) {
			#print "[D] $1\n";
			push @DIR, $CFG_DIR . "scripts/failover-$1";
			push @DIR, $CFG_DIR . "scripts/failover-$1/exec-$1";
			push @DIR, $CFG_DIR . "scripts/monitor.s/genw-$1";
		}
	}
	push @DIR, $CFG_DIR . "scripts/monitor.s/genw-remote-node";
	push @DIR, $CFG_DIR . "scripts/monitor.s/genw-esxi-inventory";
	push @DIR, $CFG_DIR . "scripts/monitor.s/genw-nic-link";
	foreach (@DIR) {
		mkdir "$_" if (!-d "$_");
	}

	#
	# Saving clp.conf
	#
	open(OUT, "> $CFG_FILE");
	foreach (@lines){
		#print "[D<] $_" if /%%/;
		if (/%%VMA1%%/)	{ s/$&/$vma_hn[0]/;}
		if (/%%VMA2%%/)	{ s/$&/$vma_hn[1]/;}
		if (/%%VMA1IP%%/)	{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2IP%%/)	{ s/$&/$vma_ip[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	#print OUT @lines;
	close(OUT);

	#
	# Creating start.sh stop.sh genw.sh
	#

	# Specify Datastore name for .vmx
	for my $i (0 .. $#vmx) {
		foreach my $vm (keys %{$vmx[$i]}) {
			$dsname = $vmx[$i]{$vm};
 			$dsname =~ s/^.*\/(.*)(\/.*){2}$/$1/;

			open(IN, "$TMPL_START") or die;
			open(OUT,"> ${CFG_DIR}scripts/failover-$vm/exec-$vm/start.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
				if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);

			open(IN, "$TMPL_STOP") or die;
			open(OUT,"> ${CFG_DIR}scripts/failover-$vm/exec-$vm/stop.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
				if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);

			open(IN, "$TMPL_MON") or die;
			open(OUT,"> ${CFG_DIR}scripts/monitor.s/genw-$vm/genw.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
				#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);
		}
	}
	open(IN, $TMPL_DIR . "genw-esxi-inventory.pl") or die;
	open(OUT,"> ${CFG_DIR}scripts/monitor.s/genw-esxi-inventory/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
		if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
		if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	&getvMADisplayName;

	open(IN, $TMPL_DIR . "genw-remote-node.pl") or die;
	open(OUT,"> ${CFG_DIR}scripts/monitor.s/genw-remote-node/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%VMADN1%%/)	{ s/$&/$vma_dn[0]/;}
		if (/%%VMADN2%%/)	{ s/$&/$vma_dn[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	open(IN, $TMPL_DIR . "genw-nic-link.pl") or die;
	open(OUT,"> ${CFG_DIR}scripts/monitor.s/genw-nic-link/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%VSWITCH%%/)	{ s/$&/$vsw/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	open(IN, $TMPL_DIR. "genw-nic-link-preaction.sh") or die;
	open(OUT,"> ${CFG_DIR}scripts/monitor.s/genw-nic-link/preaction.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		#if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		#if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%ISCSI1%%/)	{ s/$&/$iscsi_ip[0]/;}
		if (/%%ISCSI2%%/)	{ s/$&/$iscsi_ip[1]/;}
		#if (/%%VSWITCH%%/)	{ s/$&/$vsw/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	#
	# Applying the configuration
	#
	print "[I] ----------\n";
	print "[I] Applying the configuration to vMA cluster\n";
	print "[I] ----------\n";
	&execution(".\\pscp.exe -l root -pw $vma_pw[0] -r .\\conf $vma_ip[0]:/tmp");
	&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[0] $vma_ip[0] \"clpcl --suspend\"");
	&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[0] $vma_ip[0] \"clpcfctrl --push -w -x /tmp/conf\"");
	&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[0] $vma_ip[0] \"clpcl --resume\"");
	&execution(".\\plink.exe -no-antispoof -l root -pw $vma_pw[0] $vma_ip[0] \"clpcl -s -a\"");

	return 0;
}

sub setESXiIP {
	my $i = $_[0] - 1;
	print "[" . $esxi_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_ip[$i] = $ret;
	}
}

sub setESXiPwd{
	my $i = $_[0] - 1;
	print "[" . $esxi_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_pw[$i] = $ret;
	}
}

sub setvMAIP{
	my $i = $_[0] - 1;
	print "[" . $vma_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vma_ip[$i] = $ret;
	}
}

sub setvMAPwd{
	my $i = $_[0] - 1;
	print "[" . $vma_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vma_pw[$i] = $ret;
	}
}

sub setiSCSIIP{
	my $i = $_[0] - 1;
	print "[" . $iscsi_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$iscsi_ip[$i] = $ret;
	}
}

sub setiSCSIPwd{
	my $i = $_[0] - 1;
	print "[" . $iscsi_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$iscsi_pw[$i] = $ret;
	}
}

sub setDatastoreName{
	print "[" . $dsname . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$dsname = $ret;
	}
}

sub setvSwitch {
	print "[" . $vsw . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vsw = $ret;
	}
}

sub addVM {
	# Check vMA nodes connectable and get hostname
	if (&getvMAHostname()) {
		return -1;
	}

	# 追加候補を格納する二次元配列。第一次元はESXiのインデックス、第二次元は各ESXi上のVMのインデックス
	my @vms = ();

	my $i = 0;
	my $j = 0;
	my $k = 0;

	for $i (0 .. 1) {
		&execution (".\\plink.exe -no-antispoof -l root -pw $esxi_pw[$i] $esxi_ip[$i] vim-cmd vmsvc/getallvms");
		#shift @outs;	# disposing head of the list (prompt from plink)
		#shift @outs;	# disposing head of the list (message from plink)
		shift @outs;	# disposing head of the list (header of output from vim-cmd)
		foreach (@outs) {
			chomp;
			s/^.*\[(.*)\] (.*\.vmx).*$/\/vmfs\/volumes\/$1\/$2/;
		}
		push @{$vms[$i]}, @outs;
	}
	print "-----------\n";

	for $i (0 .. $#vms) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		for $j ( 0 .. $#{$vms[$i]} ) {
			$k++;
			print "[$k] $vms[$i][$j]\n";
		}
	}

	print "\nwhich to add? (1.." . ($k) . ") > ";
	$j = <STDIN>;
	chomp $j;
	#print "[D] j[$j] k[$k] #{$vms[0]}[$#{$vms[0]}]\n";
	if ($j !~ /^\d+$/) {
		return -1;
	} elsif ($j == 0) {
		return 0;
	} elsif ($j > $k) {
		return 0;
	} else {
		my $vmname = "";
		if ( $j > $#{$vms[0]} + 1 ) {
			# print "$j	$#{$vms[0]}\n";
			$vmname = $vms[1][$j - $#{$vms[0]} - 2];
		} else {
			$vmname = $vms[0][$j - 1];
		}

		$vmname =~ s/.*\/(.*)\.vmx/$1/;

		# failover-$vmname must be shorter than 31 characters (excluding termination charcter).
		$vmname =~ s/[^\w\s-]//g;
		if (length($vmname) > 22) {
			$vmname = substr ($vmname,0,22);
		}
		$vmname =~ s/-$//;

		if ( $j > $#{$vms[0]} + 1 ) {
			$vmx[1]{$vmname} = $vms[1][$j - $#{$vms[0]} - 2];
			&AddNode(1, $vmname);
		} else {
			$vmx[0]{$vmname} = $vms[0][$j - 1];
			&AddNode(0, $vmname);
		}

		print "\n[I] added [$vmname]\n";
	}
}

sub delVM {
	my $i = 0;
	my $j = 0;
	my @list = ();

	my $k = 0;
	for $i (0 .. $#vmx) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		foreach (keys %{$vmx[$i]}) {
			# print "	[$_] [$vmx[$i]{$_}]\n";
			$k++;
			print "[$k]	[$_]\n";
		}
	}

	print "\nwhich to del? (1..$k) > ";
	$j = <STDIN>;
	chomp $j;
	if ($j !~ /^\d+$/){
		return -1;
	} else {
		$k = 0;
		for $i (0 .. $#vmx) {
			foreach (keys %{$vmx[$i]}) {
				$k++;
				if ($j == $k) {
					&DelNode($i, $_);
					print "\n[I] deleted [$_]\n";
					delete $vmx[$i]{$_};
				}
			}
		}
	}
}

sub showVM {
	print "\n";
	my $i = 1;

	for $i (0 .. $#vmx) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		foreach (keys %{$vmx[$i]}) {
			# print "	[$_] [$vmx[$i]{$_}]\n";
			print "	[$_]\n";
		}
	}
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
	return 0;
}

##
# Refference
#
# http://www.atmarkit.co.jp/bbs/phpBB/viewtopic.php?topic=46935&forum=10
#
# http://pubs.vmware.com/Release_Notes/en/vcli/65/vsphere-65-vcli-release-notes.html
#	What's New in vSphere CLI 6.5
#	The ActivePerl installation is removed from the Windows installer. ActivePerl or Strawberry Perl version 5.14 or later must be installed separately before installing vCLI on a Windows system.
#
