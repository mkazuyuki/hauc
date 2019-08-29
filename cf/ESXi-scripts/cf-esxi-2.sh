#!/bin/sh

# IP Address / Netmask / IQN for ESXi Software iSCSI Adapter
IPADDR=172.31.254.3
NETMASK=255.255.255.0

esxcfg-vswitch -a Mirror_vswitch
esxcfg-vswitch -a iSCSI_vswitch
esxcfg-vswitch -a uc_vm_vswitch
esxcfg-vswitch -L vmnic1 Mirror_vswitch
esxcfg-vswitch -L vmnic2 iSCSI_vswitch
esxcfg-vswitch -L vmnic3 uc_vm_vswitch
esxcfg-vswitch -A Mirror_portgroup Mirror_vswitch
esxcfg-vswitch -A iSCSI_portgroup iSCSI_vswitch
esxcfg-vswitch -A iSCSI_Initiator iSCSI_vswitch
esxcfg-vswitch -A uc_vm_portgroup uc_vm_vswitch
esxcfg-vmknic -a -i $IPADDR -n $NETMASK iSCSI_Initiator
/etc/init.d/hostd restart
