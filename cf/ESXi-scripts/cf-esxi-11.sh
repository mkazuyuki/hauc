#!/bin/sh

# IQN for iSCSI Software Adapter on ESXi#1
IQN='iqn.1998-01.com.vmware:1'

# IP Addresss:Port for iSCSI Target
ADDR='172.31.254.10:3260'

# Enabling iSCSI Initiator
esxcli iscsi software set --enabled=true
VMHBA=`esxcli iscsi adapter list | grep 'iSCSI Software Adapter' | sed -r 's/\s.*iSCSI Software Adapter$//'`
echo [D] [$?] = VMHBA
esxcli iscsi adapter set -n ${IQN} -A ${VMHBA}
echo [D] [$?] esxcli iscsi adapter set -n ${IQN} -A ${VMHBA}
esxcli iscsi adapter discovery sendtarget add --address=${ADDR} --adapter=${VMHBA}
echo [D] [$?] esxcli iscsi adapter discovery sendtarget add --address=${ADDR} --adapter=${VMHBA}
esxcli storage core adapter rescan --all
echo [D] [$?] esxcli storage core adapter rescan --all

# Create then format the partition
i=1
for DEVICE in `esxcli storage core device list | grep "Display Name: LIO-ORG" | sed -r 's/^.*\((.*)\)/\1/' | xargs`; do
    END_SECTOR=$(eval expr $(partedUtil getptbl /vmfs/devices/disks/${DEVICE} | tail -1 | awk '{print $1 " \\* " $2 " \\* " $3}') - 1)
    partedUtil setptbl "/vmfs/devices/disks/${DEVICE}" "gpt" "1 2048 ${END_SECTOR} AA31E02A400F11DB9590000C2911D1B8 0"
    /sbin/vmkfstools -C vmfs5 -b 1m -S iSCSI${i}  /vmfs/devices/disks/${DEVICE}:1
    i=$(($i + 1))
done

# Disable ATS Heartbeat
esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5
esxcli system settings advanced set -i 0 -o /VMFS3/UseATSForHBOnVMFS5
esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5
