## Procedure

### Preparing 64bit Windows PC
- Download [**hauc-master.zip**](https://github.com/mkazuyuki/hauc/archive/master.zip) and extract.
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
- Download CentOS 7.6 (CentOS-7-x86_64-DVD-1810.iso) and put it on /vmfs/volumes/datastore1/iso/ of ESXi#1 and ESXi#2. (The directory "iso" needs to be created under /vmfs/volumes/datastore1/.)

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

Configure vSwitch, Physical NICs, Port groups, VMkernel NIC for iSCSI Initiator
- Run *cf-esxi-phase1.pl* in subfolder *cf*.

### Creating VMs for iSCSI Cluster and vMA Cluster

The disk size of the iSCSI Target which will be an ESXi Datastore for storing UC VMs can be specified at the line of **our $iscsi_size = "500G";** in *hauc.conf* in the subfolder *cf*.  
e.x. Specify as following when making a vHDD of 1024GB size

	our $iscsi_size	= "1024G";

- Run *cf-esxi-phase2-create-vm.pl* in subfolder *cf*, then VMs of iSCSI1, iSCSI2, vMA1, vMA2 are created. This will take a long time for making vmdk eager zeroed thick.

- Boot all the VMs and install CentOS.

  What needed during the installation is to select *sda* as *INSTALLATION DESTINATION* and setting *ROOT PASSWORD*.

- Configure the first network of the VMs.

  Open two ESXi Host Client (https://172.31.255.2 and https://172.31.255.3), open the console of iSCSI and vMA VMs and login to them as root user, then run the below command to set IP address so that Windows client can access to the VMs.

  - on iSCSI1 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.11/24 connection.autoconnect yes

  - on iSCSI2 console:

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.12/24 connection.autoconnect yes

  - on vMA1 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes

  - on vMA2 console:

		nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.7/24 connection.autoconnect yes

- Confirm accessibility to the following six IP addresses by using putty.
  **Do not omit this process**. The procedure hereafter assumes that SSH Hostkey entries of these IP addresses are made on Windows registry by this process.

  - 172.31.255.2 (ESXi#1)
  - 172.32.255.3 (ESXi#2)
  - 172.31.255.6 (vMA#1)
  - 172.31.255.7 (vMA#2)
  - 172.31.255.11 (iSCSI#1)
  - 172.31.255.12 (iSCSI#2)

### Setting up iSCSI Cluster

Run *cf-iscsi-phase1.pl* in the subfolder *cf*.
This configures iSCSI VMs to fill prerequisite condition for creating iSCSI Cluster.

After the completion of *cf-iscsi-phase1.pl*, both VMs are rebooted.
Wait the completion of the reboot.

- Create iSCSI Cluster

  Run *cf-iscsi-phase2.pl* in the subfolder *cf*.

After the completion of *cf-iscsi-phase2.pl*, both iscsi1 and iscsi2 are rebooted.
Open ECX WebUI (http://172.31.255.11:29003) and wait for the cluster to start the failover group "*failover-iscsi*" and synchronizing process of the mirror disk resource.

### Setting up ESXi - iSCSI Initiator

Run *cf-esxi-phase3.pl* in subfolder *cf*.
After running the command, confirm the iSCSI datastore which the iSCSI Cluster provides can be accessible from both ESXi,

### Deploying UC VMs on iSCSI datastore

Deploy UC VMs (to be protected by ECX) on *esxi1* or *esxi2*.
These VMs should be deployed on the iSCSI datastore.

### Setting up vMA Cluster

Run *cf-vma-phase2.pl* in the subfolder *cf*.
This configures vMA VMs to fill prerequisite condition for creating vMA Cluster.

After the completion of *cf-vma-phase2.pl*, both VMs are rebooted.
Wait the completion of the reboot.

- Create vMA Cluster

  Run *cf-vma-phase3.pl* in the subfolder *cf*.

After the completion of *cf-vma-phase3.pl*, both vma1 and vma2 start controlling UC VMs.
Open ECX WebUI (http://172.31.255.6:29003) and wait for the cluster to start.
