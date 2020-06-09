# IP address failover with OSPF

This document describes how to enable IP address failover by using OSPF.

## Challenge : Failover a VM having different network address than Hypervisor

Assuming a cluster with following configuration.
- 2 nodes cluster by node-A and B (hypervisor)
- each node belongs to the same network address (192.168.75.0/24)
- a VM whitch have 192.168.76.10 runs on node-A.
- the VM is configured GW1 (192.168.76.1) as default-gateway.

The diagram of the system.

	          INTERNET
	             |              +-- node-A ----------+
	    +-- GW1 -+-------+      | 192.168.75.21      |
	+---+ 192.168.76.1   +------+ 192.168.76.10 (VM) |
	|   +--------+-------+      +--------------------+
	|            |
	|            |   +-- client-A ----+
	|            +---+ 192.168.76.201 |
	|                +----------------+
	|
	: VPN
	|
	|                +-- client-B ----+
	|            +---+ 192.168.76.202 |
	|            |   +----------------+
	|            |
	|   +-- GW2 --+-------+      +-- node-B ----------+
	+---+ 192.168.76.2   +------+ 192.168.75.31      |
	    +--------+-------+      |                    |
	             |              +--------------------+
	          INTERNET


ECX issues failover of the VM from node-A to B, then the VM is relocated to node-B.


	          INTERNET
	             |              +-- node-A ----------+
	    +-- GW1 -+-------+      | 192.168.75.21      |
	+---+ 192.168.76.1   +------+                    |
	|   +--------+-------+      +--------------------+
	|            |
	|            |   +-- client-A ----+
	|            +---+ 192.168.76.101 |
	|                +----------------+
	|
	: VPN
	|
	|                +-- client-B ----+
	|            +---+ 192.168.76.102 |
	|            |   +----------------+
	|            |
	|   +-- GW2 -+-------+      +-- node-B ----------+
	+---+ 192.168.76.2   +------+ 192.168.75.31      |
	    +--------+-------+      | 192.168.76.10 (VM) |
	             |              +--------------------+
	          INTERNET


However the VM still has GW1 as default-gateway, and so, the packet from the VM to the Internet needs to go through GW1 across VPN in spite of GW2 has a route to the Internet.


## Solution : Utilising dynamic routing protocol OSPF

Before failover:  
Adding a virtual router vR1 which have 192.168.75.251, 10.0.0.254 and GW1 as default gateway.  
Adding a virtual router vR2 which have 192.168.75.252, 10.0.0.254 and GW2 as default-gateway.  
Setting 10.0.0.1 as the IP address for the VM.  
Setting a routing information for 10.0.0.0/24 network to vR1 so that hosts on 192.168.76.0/24 network are accessible to the VM.  
Configuring the VM to have 10.0.0.254 as the default-gateway.


	          INTERNET
	             |          +-- vR1 ---------+  +-- node-A ---------+
	    +-- GW1 -+-------+  | 192.168.76.251 |  | 192.168.75.21     |
	+---+ 192.168.76.1   +--+ 10.0.0.254     +--+ 10.0.0.1 (VM)     |
	|   +--------+-------+  +----------------+  +-------------------+
	|            |
	|            |   +-- client-A ----+
	|            +---+ 192.168.76.101 |
	|                +----------------+
	|
	: VPN
	|
	|                +-- client-B ----+
	|            +---+ 192.168.76.102 |
	|            |   +----------------+
	|            |
	|   +-- GW2 -+-------+  +-- vR2 ---------+  +-- node-B ---------+
	+---+ 192.168.76.2   +--+ 192.168.76.252 +--+ 192.168.75.31     |
	    +--------+-------+  |                |  |                   |
	             |          +----------------+  +-------------------+
	          INTERNET


After failover:
VM is relocated to node-B.  
vR1 stoped 10.0.0.254 interface then 10.0.0.0/24 network became unreachable.  
vR2 started 10.0.0.254 interface.  
The change of the routing information to 10.0.0.0/24 network is distributed to other routers by OSPF, then the hosts in 192.168.76.0/24 become accessible to the VM.  
The VM sill has 10.0.0.254 as default-gateway, but default-gataway of vR2 is GW2, and so, the VM become accessible to the internet via GW2.

	          INTERNET
	             |          +-- vR1 ---------+  +-- node-A ---------+
	    +-- GW1 -+-------+  | 192.168.76.251 |  | 192.168.75.13     |
	+---+ 192.168.76.1   +--+                +--+                   |
	|   +--------+-------+  +----------------+  +-------------------+
	|            |
	|            |   +-- client-A ----+
	|            +---+ 192.168.76.101 |
	|                +----------------+
	|
	: VPN
	|
	|                +-- client-B ----+
	|            +---+ 192.168.76.102 |
	|            |   +----------------+
	|            |
	|   +-- GW2 -+-------+  +-- vR2 ---------+  +-- node-B ---------+
	+---+ 192.168.76.2   +--+ 192.168.76.252 +--+ 192.168.75.14     |
	    +--------+-------+  | 10.0.0.254     |  | 10.0.0.1 (VM)     |
	             |          +----------------+  +-------------------+
	          INTERNET


The key point is to set the different network address for the VM from the surrounding environment, and to use OSPF to dynamically control the routing information to the network to which the VM belongs.

## Setup Procedure

### Preparing vR1 and 2

Adding "uc_vswitch" and "uc_portgroup" to both ESXi.

Create a VM with the following spec on each ESXi and name it vR1 and 2.

- 2 vCPU
- 4 GB Memory
- 5 GB vHDD
- 2 vNIC
	- Connect 1st NIC to "uc_portgroup" of uc_vswitch
	- Connect 2nd NIC to "uc_vm_portgroup" of uc_vm_vswitch

Install CentOS 7.6 on them.

Configure 1st NIC. Assign IP addresses which belong to existing network.

  - vR1

	nmcli connection modify ens192 ipv4.method manual ipv4.addresses 192.168.76.251/24 ipv4.gateway 192.168.76.1 connection.autoconnect yes

  - vR2

	nmcli connection modify ens192 ipv4.method manual ipv4.addresses 192.168.76.252/24 ipv4.gateway 192.168.76.2 connection.autoconnect yes

On vSphere Host Client, for both vR1 and 2, connect CDROM (CentOS 7.6) then run the following commands.

	# Setup dynamic NIC
	nmcli connection modify ens224 ipv4.method manual ipv4.addresses 10.0.0.254/24 connection.autoconnect no
	ifdown ens224

	# Configure firewalld
	systemctl stop firewalld
	systemctl disable firewalld

	# Configure selinux
	sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

	# Enable IP forwarding
	echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
	sysctl -p

	# Install Quagga
	# connect CentOS7 ISO to this VM
	mkdir /media/cdrom
	mount /dev/cdrom /media/cdrom
	yum --disablerepo=* --enablerepo=c7-media -y install quagga
	cp /usr/share/doc/quagga-0.99.22.4/ospfd.conf.sample            /etc/quagga/ospfd.conf
	sed -i -e "s/^log .*/log file \/var\/log\/quagga\/ospfd.log/"   /etc/quagga/ospfd.conf
	sed -i -e "s/^hostname .*/hostname ${HOSTNAME}/"                /etc/quagga/ospfd.conf
	sed -i -e "s/^\!router/router/"                                 /etc/quagga/ospfd.conf
	sed -i -e "s/^\!  network.*/  network 10.0.0.0\/24 area 0\n  network 192.168.75.0\/24 area 1/" /etc/quagga/ospfd.conf
	sed -i -e "s/^log .*/log file \/var\/log\/quagga\/zebra.log/"   /etc/quagga/zebra.conf
	# Start Quagga
	systemctl enable zebra
	systemctl enable ospfd
	systemctl start zebra
	systemctl start ospfd

### Configure the cluster so that controls the vR1 and 2.

Configure *ssh* access from the cluster nodes to the virtual routers.

on both node-A and B

	ssh-copy-id 192.168.76.251
	ssh-copy-id 192.168.76.252

Add exec-resource "exec-gateway" which has following scripts to the cluster.

  No need to edit stop.sh.
  edit start.sh like the sample below

	#!/bin/sh
	#**************
	#*  start.sh  *
	#**************
	
	# Parameters
	#-----------
	# Name of the failovr group
	FOG=customer1

	# IP address of virtual routers
	ROUTER1=192.168.75.251
	ROUTER2=192.168.75.252

	# Target NIC in the virtual routers to be controlled
	NIC=ens224
	#-----------

	BUF=`clpstat --local`
	PRI=`echo $BUF | sed -r 's/.*<server>[ *]{1,2}//'  | sed 's/ .*//'`
	ACT=`echo $BUF | sed -r "s/.* $FOG ([^:]*:){2} //" | sed 's/ .*//'`

	echo [D] primary : [$PRI]
	echo [D] active  : [$ACT]

	if [ $PRI = $ACT ]; then
	        ROUTER_ACT=$ROUTER1
	        ROUTER_STB=$ROUTER2
	else
	        ROUTER_ACT=$ROUTER2
	        ROUTER_STB=$ROUTER1
	fi

	echo [D] active  : [$ROUTER_ACT]
	echo [D] standby : [$ROUTER_STB]

	ret=0
	ssh $ROUTER_STB ifdown $NIC
	if [ $? -ne 0 ];then
		# On NP, ifdown for $ROUTER_STB is impossible
		echo [E] [$ROUTER_STB] [$NIC] DOWN failed
	else
		echo [I] [$ROUTER_STB] [$NIC] DOWN
	fi

	ssh $ROUTER_ACT ifup   $NIC
	if [ $? -ne 0 ];then
	        ret=1
	        echo [E] [$ROUTER_ACT] [$NIC] UP failed
	else
	        echo [I] [$ROUTER_ACT] [$NIC] UP
	fi

	exit $ret
