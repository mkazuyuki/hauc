# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux with block device backstore

This guide provides how to create iSCSI Target cluster (with block device backstore) on EXPRESSCLUSTER for Linux.

## Versions
- VMware vSphere Hypervisor 6.7U2 (VMware ESXi 6.7U2)
- CentOS 7.6 x86_64
- EXPRESSCLUSTER X for Linux 4.1.1-1

## System Requirements and Planning

### Nodes configuration

|Virtual HW	|Number, Amount	|
|:--		|:---		|
| vCPU		| 4 CPU		| 
| Memory	| 8 GB		|
| vNIC		| 3 ports       |
| vHDD		| 10 GB for OS<br>500 GB for MD1 <!-- <br>500 GB for MD2 --> |

|				| Primary		| Secondary		|
|---				|---			|---			|
| Hostname			| iscsi1		| iscsi2		|
| IP Address for Management	| 172.31.255.11/24  	| 172.31.255.12/24	|
| IP Address for iSCSI Network	| 172.31.254.11/24	| 172.31.254.12/24	|
| IP Address for Mirroring	| 172.31.253.11/24	| 172.31.253.12/24	|
| Heartbeat Timeout		| 50 sec		| <-- |
| MD1 - Cluster Partition	| /dev/sdb1		| <-- |
| MD1 - Data Partition		| /dev/sdb2		| <-- |
| <!-- MD2 - Cluster Partition	-->| <!-- /dev/sdc1 -->	|  |
| <!-- MD2 - Data Partition	-->| <!-- /dev/sdc2 -->	|  |
| FIP for iSCSI Target		| 172.31.254.10		| <-- |
| WWN for iSCSI Target		| iqn.1996-10.com.ec	| <-- |
| WWN for iSCSI Initiator 1	| iqn.1998-01.com.vmware:1	| <-- |
| WWN for iSCSI Initiator 2	| iqn.1998-01.com.vmware:2	| <-- |

## Overall Setup Procedure
- Creating VMs (*iscsi1* and *iscsi2*) one on each ESXi
- Install CentOS then ECX on them so that controls iSCSI Target.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-DVD-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Create VMs (iSCSI1 on ESXi#1, iSCSI2 on ESXi#2).

  The disk size of the iSCSI Target which will be an ESXi Datastore can be specified at the line of **my $iscsi_size	= "20G";** in *cf-iscsi-phase1.pl* in the subfolder *cf*.  
  e.x.

		my $iscsi_size	= "1024G";

  Run *cf-iscsi-phase1.pl* in subfolder *cf*.

- Boot VMs and install CentOS to them.

  What needed is to select sda as *INSTALLATION DESTINATION* and setting *ROOT PASSWORD*.

- Configure the first network of VMs

  Open ESXi Host Client, open iSCSI VMs console and login to them, then run the below command to set IP address so that Windows client can access to the VMs.

  - on iSCSI1 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.11/24 connection.autoconnect yes

  - on iSCSI2 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.12/24 connection.autoconnect yes

- Configure VMs

  Run *cf-iscsi-phase2.pl* in the subfolder *cf*.

  When you get questioned like below, push "y" then enter key.

		2019/09/02 09:26:44 [D] | WARNING - POTENTIAL SECURITY BREACH!
		2019/09/02 09:26:44 [D] | The server's host key does not match the one PuTTY has
		2019/09/02 09:26:44 [D] | cached in the registry. This means that either the
		2019/09/02 09:26:44 [D] | server administrator has changed the host key, or you
		2019/09/02 09:26:44 [D] | have actually connected to another computer pretending
		2019/09/02 09:26:44 [D] | to be the server.
		2019/09/02 09:26:44 [D] | The new ssh-ed25519 key fingerprint is:
		2019/09/02 09:26:44 [D] | ssh-ed25519 255 08:5c:13:b2:6a:24:a2:49:ea:d4:dd:a0:b7:be:8f:85
		2019/09/02 09:26:44 [D] | If you were expecting this change and trust the new key,
		2019/09/02 09:26:44 [D] | enter "y" to update PuTTY's cache and continue connecting.
		2019/09/02 09:26:44 [D] | If you want to carry on connecting but without updating
		2019/09/02 09:26:44 [D] | the cache, enter "n".
		2019/09/02 09:26:44 [D] | If you want to abandon the connection completely, press
		2019/09/02 09:26:44 [D] | Return to cancel. Pressing Return is the ONLY guaranteed
		2019/09/02 09:26:44 [D] | safe choice.

  After the completion of *cf-iscsi-phase2.pl*, both VMs are rebooted.
  Wait the completion of the reboot.

### Configuring iSCSI Target Cluster

On the client PC, run *cf-iscsi-phase3.pl* in the subfolder *cf*.

After the completion of *cf-iscsi-phase3.pl*, both iscsi1 and iscsi2 are rebooted.
Open ECX WebUI (http://172.31.255.11:29003) and wait for the cluster to start *failover-iscsi*.

## Revision history

2016.11.29 Miyamoto Kazuyuki	1st issue  
2019.06.27 Miyamoto Kazuyuki	2nd issue
