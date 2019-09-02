# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux with block device backstore

----

This guide provides how to create iSCSI Target cluster (with block device backstore) on EXPRESSCLUSTER for Linux.

----
## Versions
- vSphere Hypervisor 6.7 (vSphere ESXi 6.7)
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
- Setting up ECX then iSCSI Target on them.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-DVD-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Run the below scripts to create VMs (iSCSI1 on ESXi#1, iSCSI2 on ESXi#2).

  The disk size for iSCSI Datastore can be specified at the line of **my $DATASTORE_SIZE = "500G";** in cf-iscsi-phase1.pl.  
  e.x.

		my $DATASTORE_SIZE = "1024G";

  - Run *cf-iscsi-phase1.pl* in the Docs-Master subfolder CF for configuring the VMs.

- Boot the VMs and install CentOS to them.
	- What needed is to select sda as *INSTALLATION DESTINATION* and setting *ROOT PASSWORD*

- On ESXi Host Client, open the VMs console and login to them, then run the below commands to set IP address so that plink.exe can access to the VMs.

  - on iSCSI1 :

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.11/24 connection.autoconnect yes

  - on iSCSI2 :

		nmcli c m ens192 ipv4.method manual ipv4.addresses 172.31.255.12/24 connection.autoconnect yes

- Run *cf-iscsi-phase2.pl* in the Docs-Master subfolder CF for configuring the VMs.

  When you get questioned like below, pysh "y" then enter key.

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

<!--
for md2 do the same like md1 by using
  - *md2* as [Name]
  - */dev/sdc2* as [Data Partition Device Name] 
  - */dev/sdc1* as [Cluster Partition Device Name]
-->

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

<!--	TBD	genw-md2 の要否確認	-->

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
		> # create name=idisk2 dev=/dev/NMP2

- Creating IQN

		> cd /iscsi
		> create iqn.1996-10.com.ecx

- Assigning LUN to IQN

		> cd /iscsi/iqn.1996-10.com.ec/tpg1/luns
		> create /backstores/block/idisk1
		> # create /backstores/block/idisk2

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
