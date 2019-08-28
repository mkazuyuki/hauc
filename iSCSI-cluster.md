# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux with block device backstore

----

This guide provides how to create iSCSI Target cluster (with block device backstore) on EXPRESSCLUSTER for Linux.

----
## Versions
- vSphere Hypervisor 6.7 (vSphere ESXi 6.7)
- CentOS 7.6 x86_64
- EXPRESSCLUSTER X for Linux 4.1.1-1

## System Requirements and Planning

### Network configuration
![Network configuraiton](HAUC-NW-Configuration.png)

### Nodes configuration

|Virtual HW	|Number, Amount	|
|:--		|:---		|
| vCPU		| 4 CPU		| 
| Memory	| 8 GB		|
| vNIC		| 3 ports       |
| vHDD		| 6 GB for OS<br>500 GB for MD1<br>500 GB for MD2 |

|				| Primary		| Secondary		|
|---				|---			|---			|
| Hostname			| iscsi1		| iscsi2		|
| root password			| passwd		| passwd		|
| IP Address for Management	| 172.31.255.11/24  	| 172.31.255.12/24	|
| IP Address for iSCSI Network	| 172.31.254.11/24	| 172.31.254.12/24	|
| IP Address for Mirroring	| 172.31.253.11/24	| 172.31.253.12/24	|
| Heartbeat Timeout		| 50 sec		| <-- |
| MD1 - Cluster Partition	| /dev/sdb1		| <-- |
| MD1 - Data Partition		| /dev/sdb2		| <-- |
| MD2 - Cluster Partition	| /dev/sdc1		| <-- |
| MD2 - Data Partition		| /dev/sdc2		| <-- |
| FIP for iSCSI Target		| 172.31.254.10		| <-- |
| WWN for iSCSI Target		| iqn.1996-10.com.ec	| <-- |
| WWN for iSCSI Initiator 1	| iqn.1998-01.com.vmware:1	| <-- |
| WWN for iSCSI Initiator 2	| iqn.1998-01.com.vmware:2	| <-- |

## Overall Setup Procedure
- Creating VMs (*iscsi1* and *iscsi2*) one on each ESXi
- Setting up ECX then iSCSI Target on them.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-Minimal-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Run the below script

  you can specify disk size for iSCSI Datastore as you like at the line of "VM_DISK_SIZE2=500G" 

  - on esxi1

		#!/bin/sh -ue

		#
		# iSCSI VM
		#

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=iSCSI1
		VM_CPU_NUM=4
		VM_MEM_SIZE=8192
		VM_NETWORK_NAME1="VM Network"
		VM_NETWORK_NAME2="Mirror_portgroup"
		VM_NETWORK_NAME3="iSCSI_portgroup"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE1=6G
		VM_DISK_SIZE2=500G

		VM_DISK_PATH1=$DATASTORE_PATH/$VM_NAME/${VM_NAME}.vmdk
		VM_DISK_PATH2=$DATASTORE_PATH/$VM_NAME/${VM_NAME}_1.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		sed -i -e 's/lsilogic/pvscsi/' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		scsi0:1.deviceType = "scsi-hardDisk"
		scsi0:1.fileName = "${VM_NAME}_1.vmdk"
		scsi0:1.present = "TRUE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ethernet1.virtualDev = "vmxnet3"
		ethernet1.present = "TRUE"
		ethernet1.networkName = "$VM_NETWORK_NAME2"
		ethernet1.addressType = "generated"
		ethernet1.wakeOnPcktRcv = "FALSE"
		ethernet2.virtualDev = "vmxnet3"
		ethernet2.present = "TRUE"
		ethernet2.networkName = "$VM_NETWORK_NAME3"
		ethernet2.addressType = "generated"
		ethernet2.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		tools.syncTime = "TRUE"
		__EOF__

		# (3) Extend disk size
		vmkfstools --extendvirtualdisk $VM_DISK_SIZE1 --diskformat eagerzeroedthick $VM_DISK_PATH1

		# (4) Create disk
		vmkfstools --createvirtualdisk $VM_DISK_SIZE2 --diskformat eagerzeroedthick $VM_DISK_PATH2

		# (5) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

  - on esxi2

		#!/bin/sh -ue

		#
		# iSCSI VM
		#

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=iSCSI2
		VM_CPU_NUM=4
		VM_MEM_SIZE=8192
		VM_NETWORK_NAME1="VM Network"
		VM_NETWORK_NAME2="Mirror_portgroup"
		VM_NETWORK_NAME3="iSCSI_portgroup"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE1=6G
		VM_DISK_SIZE2=500G

		VM_DISK_PATH1=$DATASTORE_PATH/$VM_NAME/${VM_NAME}.vmdk
		VM_DISK_PATH2=$DATASTORE_PATH/$VM_NAME/${VM_NAME}_1.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		sed -i -e 's/lsilogic/pvscsi/' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		scsi0:1.deviceType = "scsi-hardDisk"
		scsi0:1.fileName = "${VM_NAME}_1.vmdk"
		scsi0:1.present = "TRUE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ethernet1.virtualDev = "vmxnet3"
		ethernet1.present = "TRUE"
		ethernet1.networkName = "$VM_NETWORK_NAME2"
		ethernet1.addressType = "generated"
		ethernet1.wakeOnPcktRcv = "FALSE"
		ethernet2.virtualDev = "vmxnet3"
		ethernet2.present = "TRUE"
		ethernet2.networkName = "$VM_NETWORK_NAME3"
		ethernet2.addressType = "generated"
		ethernet2.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		tools.syncTime = "TRUE"
		__EOF__

		# (3) Extend disk size
		vmkfstools --extendvirtualdisk $VM_DISK_SIZE1 --diskformat eagerzeroedthick $VM_DISK_PATH1

		# (4) Create disk
		vmkfstools --createvirtualdisk $VM_DISK_SIZE2 --diskformat eagerzeroedthick $VM_DISK_PATH2

		# (5) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

On both iSCSI Target VMs,

- Install CentOS and configure

  During CentOS installation, no need to set hostname and IP address. These will be setup after CentOS installation.
  After CentOS installation, login then issue the below commands

  - for iscsi1 :

		hostnamectl set-hostnme iscsi1
		systemctrl stop firewalld.service
		systemctrl disable firewalld.service
		# Disabling selinux
		sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""

		# Enabling access to the Internet
		# Configure network so that can access the internet for *yum* command.
		# The IP address in the below (192.168.137.11/24) is just an example.

		nmcli c m ens192 ipv4.method manual ipv4.addresses 192.168.137.11/24 connection.autoconnect yes
		yum -y install targetcli targetd open-vm-tools perl

		reboot

	Copy ECX rpm file and license files on iscsi1.

	Configuring iscsi1 cont'd

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.11/24 connection.autoconnect yes
		nmcli c m ens224 ipv4.method manual ipv4.addresses 172.31.253.11/24 connection.autoconnect yes
		nmcli c m ens256 ipv4.method manual ipv4.addresses 172.31.254.11/24 connection.autoconnect yes
		parted /dev/sdb mklabel msdos mkpart primary 1MiB 1025MiB mkpart primary 1025MiB 100%
		parted /dev/sdc mklabel msdos mkpart primary 1MiB 1025MiB mkpart primary 1025MiB 100%
		rpm -ivh expresscls.*.rpm
		clplcnsc -i [base-license-file]
		clplcnsc -i [replicator-license-file]
		reboot


  - for iscsi2 :

	The procedure is almost same as iscsi1. Login then configure so that can access the internet for using *yum* command. The IP address in the below (192.168.137.12/24) is just an example.

		hostnamectl set-hostnme iscsi2
		systemctrl stop firewalld.service
		systemctrl disable firewalld.service
		sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""

		nmcli c m ens192 ipv4.method manual ipv4.addresses 192.168.137.12/24 connection.autoconnect yes
		yum -y install targetcli targetd open-vm-tools perl

		reboot

	Copy ECX rpm file and license files on iscsi2.

	Configuring iscsi2 cont'd

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.12/24 connection.autoconnect yes
		nmcli c m ens224 ipv4.method manual ipv4.addresses 172.31.253.12/24 connection.autoconnect yes
		nmcli c m ens256 ipv4.method manual ipv4.addresses 172.31.254.12/24 connection.autoconnect yes
		parted /dev/sdb mklabel msdos mkpart primary 1MiB 1025MiB mkpart primary 1025MiB 100%
		parted /dev/sdc mklabel msdos mkpart primary 1MiB 1025MiB mkpart primary 1025MiB 100%

		rpm -ivh expresscls.*.rpm
		clplcnsc -i [base-license-file]
		clplcnsc -i [replicator-license-file]
		reboot

### Configuring iSCSI Target Cluster

On the client PC,

- Open Cluster WebUI ( http://172.31.255.11:29003/ )
- Change to [Config Mode] from [Operation Mode]
- Configure the cluster *iSCSI-Cluster* which have no failover-group.

	- [Cluster generation wizard]
	- Input *iSCSI-Cluster* as [Cluster name], [English] as Language > [Next]
	- [Add] > input *172.31.255.12* as [Server Name or IP Address] of secondary server > [OK]
	- Confirm *iscsi2* was added > [Next]
	- Configure Interconnect
		
		| Priority	| MDC	| iscsi1	| iscsi2	|
		|--		|--	|--		|--		|
		| 1		|	|172.31.255.11	| 172.31.255.12	|
		| 2		| mdc1	|172.31.253.11	| 172.31.253.12	|
		| 3		|	|172.31.254.11	| 172.31.254.12	|

	- [Next] > [Next] > [Next] > [Finish] > [Yes]

#### Changing Heartbeat Timeout value
- Click [Properties] button of [iSCSI-Cluster]
- [Timeout] tab > Set [Timeout] as *50* sec

#### Enabling primary node surviving on the dual-active detection
- [Recovery] tab > [Detail Config] in right hand of [Disable Shutdown When Multi-Failover-Service Detected] 
- Check [iscsi1] > [OK]
- [OK]

#### Adding the failover-group for controlling iSCSI Target service.
- click [Add group] button of [Groups]
- Set [Name] as [*failover-iscsi*]  > [Next]
- [Next]
- [Next]
- [Finish]

#### Adding the EXEC resource for MD recovery automation

This resource is enabling more automated MD recovery by supposing the node which the failover group trying to start has latest data than the other node.

- Click [Add resource] button in right side of [failover-iscsi]
- Select [EXEC resource] as [Type] > set *exec-md-recovery* as [Name] > [Next]
- **Uncheck** [Follow the default dependency] > [Next]
- [Next]
- Select start.sh then click [Replace] > Select [*exec-md-recovery.pl*]
- [Tuning] > [Maintenance] tab > input */opt/nec/clusterpro/log/exec-md-recovery.log* as [Log Output Path] > check [Rotate Log] > [OK]
- [Finish]

#### Adding the MD resource
- Click [Add resource] button in right side of [failover-iscsi]
- Select [Mirror disk resource] as [Type] > set *md1* as [Name] >  [Next]
- **Uncheck** [Follow the default dependency] > click [exec-md-recovery] > [Add] > [Next]
- [Next]
- Set
	- [none] as [File System] 
	- */dev/sdb2* as [Data Partition Device Name] 
	- */dev/sdb1* as [Cluster Partition Device Name]
- [Finish]

for md2 do the same like md1 by using
  - *md2* as [Name]
  - */dev/sdc2* as [Data Partition Device Name] 
  - */dev/sdc1* as [Cluster Partition Device Name]

#### Adding the execute resource for controlling target service
- Click [Add resource] button in right side of [failover-iscsi]
- Select [EXEC resource] as [Type] > set *exec1* as [Name] > [Next]
- [Next]
- [Next]
- Select start.sh then click [Edit]
  - Add below lines.

		#!/bin/bash
		echo "Starting iSCSI Target"
		systemctl start target
		echo "Started  iSCSI Target"

- Select stop.sh then click [Edit]
  - Add below lines.

		#!/bin/bash
		echo "Stopping iSCSI Target"
		systemctl stop target
		echo "Stopped  iSCSI Target"

- [Finish]

#### Adding floating IP resource for iSCSI Target
- Click [Add resource] button in right side of [failover-iscsi]
- Select [Floating IP resource] as [Type] > set *fip1* as [Name] > [Next]
- [Next]
- [Next]
- Set *172.31.254.10* as [IP Address]
- Click [Finish]

#### Adding the first custom monitor resource for automatic MD recovery on Red(Active)-Red status
- Click [Add monitor Resource] button in right side of [Monitors]
  - [Info] section
    - select [Custom monitor] as [Type] > input *genw-md* as [Name] > [Next]
  - [Monitor (common)] section
    - input *60* as [Wait Time to Start Monitoring]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - select [md1] > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-md.pl* > [Open] > [Yes]
    - input */opt/nec/clusterpro/log/genw-md.log* as [Log Output Path] > check [Rotate Log]
    - [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - [Finish]

<!--	TBD	genw-md2 ‚Ì—v”ÛŠm”F	-->

#### Adding the second custom monitor resource for keeping remote iSCSI VM and ECX online.
- Click [Add monitor Resource] button in right side of [Monitors]
  - [Info] section
    - select [Custom monitor] as [type] > input *genw-remote-node* as [Name]> [Next]
  - [Monitor (common)] section
    - select [Always] as [Monitor Timing]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-remote-node.pl* > [Open] > [Yes]
    - [Edit]
      - write $VMNAME1 = "iscsi1" as VM name in the esxi1 inventory
      - write $VMNAME2 = "iscsi2" as VM name in the esxi2 inventory
      - write $VMIP1 = "172.31.255.11" as IP address of iscsi1
      - write $VMIP2 = "172.31.255.12" as IP address of iscsi2
      - write $VMK1 = "172.31.255.2" as IP address of esxi1 accessing from iscsi1
      - write $VMK2 = "172.31.255.3" as IP address of esxi2 accessing from iscsi2
    - input */opt/nec/clusterpro/log/genw-remote-node.log* as [Log Output Path] > check [Rotate Log] > [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action] > [Finish]

#### Adding the third custom monitor resource for updating arp table
- Click [Add monitor Resource] button in right side of [Monitors]
  - [Info] section
    - select [Custom monitor] as [type] > input *genw-arpTable* as[Name] > [Next]
  - [Monitor (common)] section
    - input *30* as [Interval]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - select [fip1] > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-arpTable.sh* > [Open] > [Yes]
    - input */opt/nec/clusterpro/log/genw-arpTable.log* as [Log Output Paht] > check [Rotate Log] > [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action] > [Finish]

#### Applying the configuration
- Click [Apply the Configuration File]
- Reboot iscsi1, iscsi2 and wait for the completion of starting of the cluster *failover-iscsi*

### Configuring iSCSI Target
On iscsi1, create block backstore and configure it as backstore for the iSCSI Target.
- Login to the console of iscsi1.

- Start (iSCSI) target configuration tool

		# targetcli

- Unset automatic save of the configuration for safe.

		> set global auto_save_on_exit=false

- Create fileio backstore (*idisk*) which have required size on mount point of the mirror disk

		> cd /backstores/block
		> create name=idisk1 dev=/dev/NMP1
		> create name=idisk2 dev=/dev/NMP2

- Creating IQN

		> cd /iscsi
		> create iqn.1996-10.com.ecx

- Assigning LUN to IQN

		> cd /iscsi/iqn.1996-10.com.ec/tpg1/luns
		> create /backstores/block/idisk1
		> create /backstores/block/idisk2

- Allow machine (IQN of iSCSI Initiator) to scan the iSCSI target.

		> cd /iscsi/iqn.1996-10.com.ecx/tpg1/acls
		> create iqn.1998-01.com.vmware:1
		> create iqn.1998-01.com.vmware:2

- Save config and exit.

		> cd /
		> saveconfig
		> exit

- Copy the saved target configuration to the other node.

		# scp /etc/target/saveconfig.json iscsi2:/etc/target/

## Revision history

2016.11.29 Miyamoto Kazuyuki	1st issue  
2019.06.27 Miyamoto Kazuyuki	2nd issue
