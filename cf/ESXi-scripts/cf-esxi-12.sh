#!/bin/sh

# IQN for iSCSI Software Adapter on ESXi#2
IQN='iqn.1998-01.com.vmware:2'

# IP Addresss:Port for iSCSI Target
ADDR='172.31.254.10:3260'

# Enabling iSCSI Initiator
esxcli iscsi software set --enabled=true
VMHBA=`esxcli iscsi adapter list | grep 'iSCSI Software Adapter' | sed -r 's/\s.*iSCSI Software Adapter$//'`
esxcli iscsi adapter set -n ${IQN} -A ${VMHBA}
esxcli iscsi adapter discovery sendtarget add --address=${ADDR} --adapter=${VMHBA}
esxcli storage core adapter rescan --all

# Disable ATS Heartbeat
esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5
esxcli system settings advanced set -i 0 -o /VMFS3/UseATSForHBOnVMFS5
esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5
