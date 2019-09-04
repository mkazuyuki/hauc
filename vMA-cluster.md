# Howto setup vMA Cluster on EXPRESSCLUSTER for Linux

This guide provides how to create Management VM Cluster on EXPRESSCLUSTER for Linux.

## Versions
- VMware vSphere Hypervisor 6.7U2 (VMware ESXi 6.7U2)
- CentOS 7.6 x86_64
- EXPRESSCLUSTER X for Linux 4.1.1-1

## System Requirements and Planning

### Nodes configuration

|Virtual HW	|Number, Amount	|
|:--		|:---		|
| vCPU		| 2 CPU		| 
| Memory	| 4 GB		|
| vNIC		| 1 port	|
| vHDD		| 6 GB		|

|		| Primary		| Secondary		|
|---		|---			|---			|
| Hostname	| vma1			| vma2			|
| IP Address	| 172.31.255.6/24	| 172.31.255.7/24	|

## Overall Setup Procedure
- Creating VMs (*vma1* and *vma2*) one on each ESXi
- Install CentOS then ECX on them so that controls UC VMs.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-DVD-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Create VMs (vMA1 on ESXi#1, vMA2 on ESXi#2).

  Run *cf-vma-phase1.pl* in subfolder *cf*.

- Boot VMs and install CentOS to them.

  What needed is to select sda as *INSTALLATION DESTINATION* and setting *ROOT PASSWORD*.

- Configure the first network of VMs

  Open ESXi Host Client, open vMA VMs console and login to them, then run the below command to set IP address so that Windows client can access to the VMs.

  - on vMA1 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes

  - on vMA2 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.7/24 connection.autoconnect yes

- Configure VMs

  Run *cf-vma-phase2.pl* in the subfolder *cf*.

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

  After the completion of *cf-vma-phase2.pl*, both VMs are rebooted.
  Wait the completion of the reboot.

### Configuring vMA Cluster

  Run *cf-vma-phase3.pl* in the subfolder *cf*.

After the completion of *cf-vma-phase3.pl*, both vma1 and vma2 start controlling UC VMs.
Open ECX WebUI (http://172.31.255.6:29003) and wait for the cluster to start.

## Revision history
2017.02.03	Miyamoto Kazuyuki	1st issue  
2019.06.27	Miyamoto Kazuyuki	2nd issue  
2019.08.22	Miyamoto Kazuyuki	3rd issue  
