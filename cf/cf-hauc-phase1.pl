#!/usr/bin/perl -w

#
# This script edit HAUC configuration files (hauc.conf)
# 

use strict;
use warnings;

# Parameters
#-------------------------------------------------------------------------------
our @esxi_ip;
our @esxi_pw;
our @esxi_isa_ip;
our @esxi_isa_nm;

our @iscsi_vname;
our @iscsi_ds;
our @iscsi_ip1;
our @iscsi_ip2;
our @iscsi_ip3;
our $iscsi_fip;
our @iscsi_pw;

our @vma_vname;
our @vma_ip;
our @vma_pw;

our $dsname;
our $advertised_hdd_size;
our $managed_vmdk_size;

our $vsw;
#-------------------------------------------------------------------------------
my $FILEIN  = "./hauc.conf";
my $FILEOUT = "./hauc.conf";

require $FILEIN or die "file not found hauc.pl";
my @menu;
my @outs = (); 

while ( 1 ) {
	if ( ! &select ( &menu ) ) {last}
}
exit;

#
# subroutines
#-------------------------------------------------------------------------------
sub menu {
	@menu = (
		'EXIT without saving changes',
		'SAVE Changes and EXIT',
		'SAVE Changes and RUN',
		'ESXi#1 IP                    : ' . $esxi_ip[0],
		'ESXi#2 IP                    : ' . $esxi_ip[1],
		'ESXi#1 root password         : ' . $esxi_pw[0],
		'ESXi#2 root password         : ' . $esxi_pw[1],
		'ESXi#1 iSCSI Adapter IP      : ' . $esxi_isa_ip[0],
		'ESXi#2 iSCSI Adapter IP      : ' . $esxi_isa_ip[1],
		'ESXi#1 iSCSI Adapter Netmask : ' . $esxi_isa_nm[0],
		'ESXi#2 iSCSI Adapter Netmask : ' . $esxi_isa_nm[1],

		'iSCSI#1 Display name         : ' . $iscsi_vname[0],
		'iSCSI#2 Display name         : ' . $iscsi_vname[1],
		'iSCSI#1 residing Datastore   : ' . $iscsi_ds[0],
		'iSCSI#2 residing Datastore   : ' . $iscsi_ds[1],
		'iSCSI#1 IP 1                 : ' . $iscsi_ip1[0],
		'iSCSI#2 IP 1                 : ' . $iscsi_ip1[1],
		'iSCSI#1 IP 2                 : ' . $iscsi_ip2[0],
		'iSCSI#2 IP 2                 : ' . $iscsi_ip2[1],
		'iSCSI#1 IP 3                 : ' . $iscsi_ip3[0],
		'iSCSI#2 IP 3                 : ' . $iscsi_ip3[1],
		'iSCSI FIP                    : ' . $iscsi_fip,
		'iSCSI#1 root password        : ' . $iscsi_pw[0],
		'iSCSI#2 root password        : ' . $iscsi_pw[1],
		'iSCSI Datastore name         : ' . $dsname,

		'vMA#1 Display name           : ' . $vma_vname[0],
		'vMA#2 Display name           : ' . $vma_vname[1],
		'vMA#1 IP                     : ' . $vma_ip[0],
		'vMA#2 IP                     : ' . $vma_ip[1],
		'vMA#1 root password          : ' . $vma_pw[0],
		'vMA#2 root password          : ' . $vma_pw[1],

		'Advertised HDD size          : ' . $advertised_hdd_size,
		'Managed VMs disk size total  : ' . $managed_vmdk_size,
		'vSwitch name                 : ' . $vsw,
	);
	my $i = 0;
	print "\n--------\n";
	foreach (@menu) {
		if ($i < 10) {
			print "[" . ($i++) . "]  $_\n";
		} else {
			print "[" . ($i++) . "] $_\n";  
		}
	}
	print "--------\n";
	print "(0.." . ($i - 1) . ") > ";

	my $ret = <STDIN>;
	chomp $ret;
	return $ret;
}

sub select {
	my $i = shift;
	if ($i !~ /^\d+$/){
		print "invalid (should be numeric)\n";
		return -1;
	}
	elsif ( $menu[$i] =~ /EXIT without saving changes/ ) {
		&Log("\nBye.\n");
		return 0;
	}
	elsif ( $menu[$i] =~ /SAVE Changes and EXIT/ ) {
		&Save;
		&Log("\nThe configuration was saved.\nBye.\n");
		return 0;
	}
	elsif ( $menu[$i] =~ /SAVE Changes and RUN/ ) {
		&Save;
		&Log("\nThe configuration was saved.\n");

		&Log("Running cf-esxi-phase1.pl\n");
		system("perl .\\cf-esxi-phase1.pl");

		&Log("Running cf-esxi-phase2-create-vm.pl\n");
		system("perl .\\cf-esxi-phase2-create-vm.pl");

		&Log("Boot all the VMs and install CentOS for next phase.\n");
		return 0;
	}
	elsif ( $menu[$i] =~ /ESXi#([12]) IP/ )			{ &setval_ip(\$esxi_ip[$1-1]); }
	elsif ( $menu[$i] =~ /ESXi#([12]) root password/ )		{ &setval(\$esxi_pw[$1-1]); }
	elsif ( $menu[$i] =~ /ESXi#([12]) iSCSI Adapter IP/ )		{ &setval_ip(\$esxi_isa_ip[$1-1]); }
	elsif ( $menu[$i] =~ /ESXi#([12]) iSCSI Adapter Netmask/ )	{ &setval_ip(\$esxi_isa_nm[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) Display name/ )		{ &setval(\$iscsi_vname[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) residing Datastore/ )	{ &setval(\$iscsi_ds[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) IP 1/ )			{ &setval_ipnm(\$iscsi_ip1[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) IP 2/ )			{ &setval_ipnm(\$iscsi_ip2[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) IP 3/ )			{ &setval_ipnm(\$iscsi_ip3[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI FIP/ )				{ &setval_ip(\$iscsi_fip); }
	elsif ( $menu[$i] =~ /iSCSI#([12]) root password/ )		{ &setval(\$iscsi_pw[$1-1]); }
	elsif ( $menu[$i] =~ /iSCSI Datastore name/ )			{ &setval(\$dsname); }
	elsif ( $menu[$i] =~ /vMA#([12]) Display name/ )		{ &setval(\$vma_vname[$1-1]); }
	elsif ( $menu[$i] =~ /vMA#([12]) IP/ )				{ &setval_ip(\$vma_ip[$1-1]); }
	elsif ( $menu[$i] =~ /vMA#([12]) root password/ )		{ &setval(\$vma_pw[$1-1]); }
	elsif ( $menu[$i] =~ /Advertised HDD size/ )			{ &setval(\$advertised_hdd_size); }
	elsif ( $menu[$i] =~ /Managed VMs disk size total/ )		{ &setval(\$managed_vmdk_size); }
	elsif ( $menu[$i] =~ /vSwitch name/ )				{ &setval(\$vsw); }
	else { print "[$i] Invalid.\n"; }
	return $i;
}

sub setval {
	my ($val) = @_;
	print "[" . $$val . "] > ";
	my $ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$$val = $ret;
	}
}

sub setval_ip {
	my ($val) = @_;
	print "[" . $$val . "] > ";
	my $ret = <STDIN>;
	chomp $ret;
	if ($ret =~ /^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/) {
		$$val = $ret;
	} else {
		print "[E] Invalid\n";
	}
}
sub setval_ipnm {
	my ($val) = @_;
	print "[" . $$val . "] > ";
	my $ret = <STDIN>;
	chomp $ret;
	if ($ret =~ /^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\/(\d{1,2})$/) {
		if (($4 > 0) && ($4 < 32)) {
			$$val = $ret;
		} else {
			print "[E] Invalid\n";
		}
	} else {
		print "[E] Invalid\n";
	}
}
sub Save {
	open(IN, "./hauc.conf") or die "file not found hauc.conf";
	my @CONF = <IN>;
	close(IN);

	foreach (@CONF) {
		if (/esxi_ip/)			{ s/'.*', '.*'/'$esxi_ip[0]', '$esxi_ip[1]'/; }
		if (/esxi_pw/)			{ s/'.*', '.*'/'$esxi_pw[0]', '$esxi_pw[1]'/; }
		if (/esxi_isa_ip/)		{ s/'.*', '.*'/'$esxi_isa_ip[0]', '$esxi_isa_ip[1]'/; }
		if (/esxi_isa_nm/)		{ s/'.*', '.*'/'$esxi_isa_nm[0]', '$esxi_isa_nm[1]'/; }
		if (/vsw/)			{ s/'.*'/'$vsw'/; }
		if (/iscsi_vname/)		{ s/'.*', '.*'/'$iscsi_vname[0]', '$iscsi_vname[1]'/; }
		if (/iscsi_ds/)			{ s/'.*', '.*'/'$iscsi_ds[0]', '$iscsi_ds[1]'/; }
		if (/iscsi_ip1/)		{ s/'.*', '.*'/'$iscsi_ip1[0]', '$iscsi_ip1[1]'/; }
		if (/iscsi_ip2/)		{ s/'.*', '.*'/'$iscsi_ip2[0]', '$iscsi_ip2[1]'/; }
		if (/iscsi_ip3/)		{ s/'.*', '.*'/'$iscsi_ip3[0]', '$iscsi_ip3[1]'/; }
		if (/iscsi_fip/)		{ s/'.*'/'$iscsi_fip'/; }
		if (/iscsi_pw/)			{ s/'.*', '.*'/'$iscsi_pw[0]', '$iscsi_pw[1]'/; }
		if (/dsname/)			{ s/'.*'/'$dsname'/; }
		if (/advertised_hdd_size/)	{ s/= .*;/= $advertised_hdd_size;/; }
		if (/managed_vmdk_size/)	{ s/= .*;/= $managed_vmdk_size;/; }
		if (/vma_vname/)		{ s/'.*', '.*'/'$vma_vname[0]', '$vma_vname[1]'/; }
		if (/vma_ip/)			{ s/'.*', '.*'/'$vma_ip[0]', '$vma_ip[1]'/; }
		if (/vma_pw/)			{ s/'.*', '.*'/'$vma_pw[0]', '$vma_pw[1]'/; }
	}

	open(OUT, "> $FILEOUT") or die "file not found hauc.conf";
	print OUT @CONF;
	close(OUT);
	return 0;
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

	open(LOG, ">> cf-hauc-phase1.log");
	print LOG "$date $_[0]";
	close(LOG);

	return 0;
}
