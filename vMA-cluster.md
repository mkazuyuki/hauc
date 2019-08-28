# Howto setup vMA Cluster on EXPRESSCLUSTER for Linux

This guide provides how to create Management VM Cluster on EXPRESSCLUSTER for Linux.


## Versions
- VMware vSphere Hypervisor 6.7U2 (VMware ESXi 6.7U2)
- CentOS 7.6 x86_64
- EXPRESSCLUSTER X for Linux 4.1.1-1

## Network configuration
![Network configuraiton](HAUC-NW-Configuration.png)

## Nodes configuration

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
- Install CentOS and EC on them.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-Minimal-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Run the below script

  - on esxi1

		#!/bin/sh -ue

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=vMA1
		VM_CPU_NUM=2
		VM_MEM_SIZE=4096
		VM_NETWORK_NAME1="VM Network"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE=6g

		VM_DISK_PATH=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		__EOF__

		# (3) Extend disk size
		vmkfstools -X $VM_DISK_SIZE $VM_DISK_PATH 

		# (4) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

  - on esxi2

		#!/bin/sh -ue

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=vMA2
		VM_CPU_NUM=2
		VM_MEM_SIZE=4096
		VM_NETWORK_NAME1="VM Network"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE=6g

		VM_DISK_PATH=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		__EOF__

		# (3) Extend disk size
		vmkfstools -X $VM_DISK_SIZE $VM_DISK_PATH 

		# (4) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

- Boot vMA1 and vMA2 and install CentOS

- Configure hostname, IP address, firewall, selinux, ssh

  vMA1, 2 need to be accessible to the internet during the setup.
  In the following, *ens160* assumes to be connected to *VM Network* port group and obtain network configuration from DHCP server.
  When DHCP is abscent, use *nmtui* command or edit /etc/sysconfig/network-scripts/ifcfg-ens160 so that can access the Internet.

  - on vma1

		ifup ens160
		hostnamectl set-hostname vma1
		systemctl stop firewalld.service
		systemctl disable firewalld.service
		sed -i -e 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
		reboot

  - on vma2

		ifup ens160
		hostnamectl set-hostname vma2
		systemctl stop firewalld.service
		systemctl disable firewalld.service
		sed -i -e 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
		reboot

- Install EC
  - Login to vma1 and vma2 then execute following commands.
  - Download, unzip, install the packeage then install the license 

		# curl -O https://www.nec.com/en/global/prod/expresscluster/en/trial/zip/ecx41l_x64.zip
		# yum install unzip
		# unzip ecx411_x64.zip
		# rpm -ivh ecx41l_x64/Linux/4.1/en/server/expresscls-4.1.1-1.x86_64.rpm
		# clplcnsc -I [YOUR_LICENSE_FILE]
		
  - Delete unnecessary files

		# rm -rf ecx41l_x64/ ecx41l_x64.zip

- Install VMware Tools

		# yum install open-vm-tools

- Reconfigure IP address

  - on vma1

		# nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes
		# systemctl restart network

  - on vma2

		# nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.7/24 connection.autoconnect yes
		# systemctl restart netwrok

## Revision history
2017.02.03	Miyamoto Kazuyuki	1st issue  
2019.06.27	Miyamoto Kazuyuki	2nd issue  
2019.08.22	Miyamoto Kazuyuki	3rd issue