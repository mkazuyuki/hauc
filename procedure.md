## Procedure

### Preparing 64bit Windows PC
- Download [**hauc-master.zip**](https://github.com/mkazuyuki/hauc/archive/master.zip) and extract.
	- Edit cf/hauc.conf so that match to your environment.

- Download [**ECX**](https://www.nec.com/en/global/prod/expresscluster/en/trial/zip/ecx41l_x64.zip)
	-  Extract it and copy *expresscls-4.1.1-1.x86_64.rpm* in it to the subfolder *cf*.

- Put the (trial) license files of ECX to the subfolder *cf*.
	- ECX4.x-lin1.key
	- ECX4.x-Rep-lin1.key
	- ECX4.x-Rep-lin2.key

- Download
	[putty](https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe),
	[plink](https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe),
	[pscp](https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe)
  to the subfolder *cf*.

- Download and install [Strawberry Perl](http://strawberryperl.com/).

- Configure the Windows PC to have IP address such as 172.31.255.100/24 so that becomes IP reachable to **172.31.255.0/24** network where the ESXi hosts exists.

- Download CentOS 7.6 ([CentOS-7-x86_64-DVD-1810.iso](http://archive.kernel.org/centos-vault/7.6.1810/isos/x86_64/CentOS-7-x86_64-DVD-1810.iso)) and put it on /vmfs/volumes/datastore1/iso/ of ESXi#1 and ESXi#2. (The directory "iso" needs to be created under /vmfs/volumes/datastore1/.)

### Setting up ESXi - Network

Install vSphere ESXi then set up IP address as following.

|		| Primary ESXi	| Secondary ESXi	|
|:---		|:---		|:---			|
| Management IP	| 172.31.255.2	| 172.31.255.3		|

Start ssh service and configure it to start automatically.
- Open vSphere Host Client for ESXi#1 (http://172.31.255.2/) and ESXi#2 (http://172.31.255.3/)
  - [Manage] in [Navigator] pane > [Services] tab
    - [TSM-SSH] >  [Actions] > [Start]
    - [TSM-SSH] >  [Actions] > [Polilcy] > [Start and stop with host]

Setup NTP servers
- On vSphere Host Client for both ESXi,
  - [Manage] in [Navigator] pane > [System] tab
  - [Time and date] > [Edit settings]
  - Select [Use Network Time Protocol (enable NTP client)] > Select [Start and stop with host] as [NTP service startup policy] > input IP address of NTP server for the configuring environment as [NTP servers]

Configure vSwitch, Physical NICs, Port groups, VMkernel NIC for iSCSI Initiator
- Run *cf-esxi-phase1.pl* in subfolder *cf*.

### Setting up ESXi - Datastore

If storage (HDD) dedicated for UC VMs is prepared on each ESXi, set up the storage as **datastore2**.

- On vSphere Host Client for ESXi#1 and ESXi#2,
	- [Storage] in [Navigator] pane > [Datastores] tab > [New datastore] 
	- Select [Create new VMFS datastore] > [Next] > input [datastore2] as [name] > Select the storege device for UC VMs.

- Edit the lines of @iscsi_ds in *hauc.conf* in subfolder *cf* as

	  our @iscsi_ds	= ('datastore2', 'datastore2');

### Creating VMs for iSCSI Cluster and vMA Cluster

The disk size of the iSCSI Target which will be an ESXi Datastore for storing UC VMs can be specified at the line of **our $iscsi_size = "500G";** in *hauc.conf* in the subfolder *cf*.  
e.x. Specify as following when making a vHDD of 1024GB size

	our $iscsi_size	= "1024G";

The size itself may be calculated from *Advertised HDD size in GB* as following.

$iscsi_size  
= ROUNDDOWN( { ( { (Advertised HDD size in GB) * 0.9313 GiB/GB * Safety Margin} * { (1 - 5% of VMFS overhead) * Safety Margin } ) -( .vswp + logs etc. + sda of vMA VM in GB ) - ( .vswp + log etc. + sda of iSCSI VM in GB ) } * Safety Margin )

= ROUNDDOWN({({(Advertised HDD size in GB) * 0.9313 * 0.99} * {(1-0.05) * 0.99}) - (2+0.2+6) - (2+0.2+9)} * 0.99)

= ROUNDDOWN(((Advertised HDD size in GB) * 0.858457485765 - 14.751 ), 0)

- Run *cf-esxi-phase2-create-vm.pl* in subfolder *cf*, then VMs of iSCSI1, iSCSI2, vMA1, vMA2 are created. This takes a long time for making vmdk eager zeroed thick.

**NOTE** : If you run *cf-esxi-phase2-create-vm.pl* once again, before that, please delete the VM (iscsi1, iscsi2, vma1, vma2) at vSphere Host Client and confirm the ESXi datastore does not have the VM folders.

<!--
**NOTE** : **If you import OVA (exported VM file) of iSCSI VMs, before that, delete iSCSI1 and iSCSI2 at the both vSphere Host Client. And ignore the procedures regarding iSCSI VMs till the section "Setting up ESXi - iSCSI Initiator".**
-->

- Boot all the VMs and install CentOS.

  What needed during the installation is to select *sda* as *INSTALLATION DESTINATION* and setting *ROOT PASSWORD*.

- Configure the first network of the VMs.

  Open two ESXi Host Client ( https://172.31.255.2 and https://172.31.255.3 ), open the console of iSCSI and vMA VMs and login to them as root user, then run the below command to set IP address so that Windows client can access to the VMs.

  - on iSCSI1 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.11/24 connection.autoconnect yes

  - on iSCSI2 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.12/24 connection.autoconnect yes

  - on vMA1 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes

  - on vMA2 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.7/24 connection.autoconnect yes

Confirm accessibility to the following six IP addresses from Windows PC by using putty.
**Do not omit this process**. The procedure hereafter assumes that SSH Hostkey entries of these IP addresses are made on Windows registry by this process.

  - 172.31.255.2 (ESXi#1)
  - 172.32.255.3 (ESXi#2)
  - 172.31.255.6 (vMA1)
  - 172.31.255.7 (vMA2)
  - 172.31.255.11 (iSCSI1)
  - 172.31.255.12 (iSCSI2)

### Setting up iSCSI Cluster

At the command prompt of Windows PC,

- Run *cf-iscsi-phase1.pl* in the subfolder *cf* for configuring iSCSI VMs to fill pre-conditions of creating iSCSI Cluster.
  On the *cf-iscsi-phase1.pl* completion, both VMs are rebooted. Wait the completion of the reboot.

- Run *cf-iscsi-phase2.pl* in the subfolder *cf* to create iSCSI Cluster.
  On the *cf-iscsi-phase2.pl* completion, both iscsi1 and iscsi2 are rebooted.

- Open ECX WebUI (http://172.31.255.11:29003) and wait the cluster starting,
  the failover group "*failover-iscsi*" activating and completion of the mirror disk resource synchronizing.

### Setting up ESXi - iSCSI Initiator

Run *cf-esxi-phase3.pl* in subfolder *cf*.
After running the command, confirm the iSCSI datastore which the iSCSI Cluster provides can be accessible from both ESXi,

### Deploying UC VMs on iSCSI datastore

Deploy UC VMs (to be protected by ECX) on *esxi1* or *esxi2*.
These VMs should be deployed on the iSCSI datastore.

### Setting up vMA Cluster

Run *cf-vma-phase2.pl* in the subfolder *cf*.
This configures vMA VMs to fill prerequisite condition for creating vMA Cluster and installing ECX (and its license).

After the completion of *cf-vma-phase2.pl*, both VMs are rebooted.
Wait the completion of the reboot.

- Create vMA Cluster

  Run *cf-vma-phase3.pl* in the subfolder *cf*.

After the completion of *cf-vma-phase3.pl*, both vma1 and vma2 start controlling UC VMs.
Open ECX WebUI (http://172.31.255.6:29003) and wait for the cluster to start.
