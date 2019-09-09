# HAUC setup howto

This guide provides how to set up HAUC (Highly Available Unified Communications). The guide assumes its readers to have Linux system administration knowledge and skills with experience in installation and configuration of Storages, and Networks.

## Overview

The general procedure to deploy HAUC on ESXi boxes (Primary and Standby) consists of the following major steps:

1. Perform system planning to determine requirements and specify specific configuration settings.
2. Set up Primary and Standby ESXi.
3. Deploy *iSCSI Target Cluster*.
4. Connect ESXi hosts to the iSCSI Target.
5. Deploy UC VMs.
6. Deploy *vMA Cluster* which managing UC VMs.

## Versions
- vSphere ESXi 6.7 U2
- Strawberry Perl 5.30.0.1 (64bit)   (http://strawberryperl.com/)
- EXPRESSCLUSTER X 4.1 for Linux (4.1.1-1)

## System Requirements and Planning

* Requirement for 2 Physical ESXi servers

  | Portion	| Description 
  |:--		|:--
  | CPU Cores	| (Cores for VMkernel) + (Cores for UC VMs) +   (4 Cores for iSCSI VM) + (2 Cores for vMA VM)
  | Memory	| (2GB for VMkernel) + (required amount for UC   VMs) + (8GB for iSCSI VM) + (4GB for vMA VM)
  | LAN Port	| 4 LAN ports (iSCSI, ECX data-mirroring,   Management, UC)
  | Storage	| (60GB for ESXi system) + (required amount   for UC VMs) + (6GB for iSCSI VM) + (6GB for vMA VM)

* Network configuration
  ![Network configuraiton](HAUC-NW-Configuration.png)

* ESXi configuration

  |							|   Primary ESXi			| Secondary ESXi	  	|
  |:---							|:---  					|:---			  	|
  | IP address for Management				|   172.31.255.2			| 172.31.255.3		  	|
  | IP address for VMkernel(Software iSCSI Adapter)	|   172.31.254.2			| 172.31.254.3		  	|
  | iSCSI Initiator WWN					|   iqn.1998-01.com.vmware:1		|  iqn.1998-01.com.vmware:2 	|

## [Procedure](procedure.md)

## Common Maintenance Tasks

### The graceful shutdown procedure for both ESXi
1. Issue cluster shutdown for the vMA Cluster. Then all the UC VMs and vMA VMs are shutted down.
2. Issue cluster shutdown for the iSCSI Cluster. Then both iSCSI Target VMs are shutted down.
3. Issue shutdown for both the ESXi.

### Stopping either of nodes in vMA Cluster or iSCSI Target Cluster
- When intentionally shutdown the vMA VM or iSCSI VM, "suspend" the *genw-remote-node* before it. *genw-remote-node* in the Cluster periodically executes "power on" for another VM. 
- When intentionally stop the cluster service, "suspend" the *genw-remote-node* before it. *genw-remote-node* in the cluster periodically executes "starting cluster service" for another VM.

### Deleting / Adding UC VM on vMA Cluster
- re-run the *cf-vma-phase3.pl*

## Where to go for more information

For general information about EXPRESSCLUSTER, please visit the product [web site](http://www.nec.com/expresscluster).

[The following guides are available](http://www.nec.com/global/prod/expresscluster/en/support/manuals.html) for instant support:  

- Getting Started Guide - General cluster concepts and overview of EXPRESSCLUSTER functionality.

- Installation Guide - EXPRESSCLUSTER installation and configuration procedures in detail.

- Reference Guide - The reference of commands that can be put in EXPRESSCLUSTER scripts and maintenance commands that can be executed from the server command prompt.

<!--

----

## Disclaimer

NEC Corporation assumes no responsibility for technical or editorial mistakes in or omissions from this document. To obtain the benefits of the product, it is the customers responsibility to install and use the product in accordance with this document. The copyright for the contents of this document belongs to NEC Corporation.

## Revision history

- 2017.08.28 Miyamoto Kazuyuki	1st issue
- 2018.10.22 Miyamoto Kazuyuki	2nd issue
- 2019.06.27 Miyamoto Kazuyuki	3rd issue

-->
