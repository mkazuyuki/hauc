#!/bin/sh -ue

# (0) Parameters
DATASTORE_PATH=/vmfs/volumes/datastore1
ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-DVD-1810.iso
VM_NAME=iSCSI1
VM_CPU_NUM=4
VM_MEM_SIZE=8192
VM_NETWORK_NAME1="VM Network"
VM_NETWORK_NAME2="Mirror_portgroup"
VM_NETWORK_NAME3="iSCSI_portgroup"
VM_GUEST_OS=centos7-64
VM_CDROM_DEVICETYPE=cdrom-image
VM_DISK_SIZE1=9G
VM_DISK_SIZE2=500G

VM_DISK_PATH1=$DATASTORE_PATH/$VM_NAME/${VM_NAME}.vmdk
VM_DISK_PATH2=$DATASTORE_PATH/$VM_NAME/${VM_NAME}_1.vmdk
VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

# (0) Clean up existing VM
vid=`vimd-cmd vmsvc/getallvms | grep ${VM_NAME} | awk '{print $1}'`
if [ ${vid} ]; then
	vim-cmd vmsvc/unregister $vid
fi
rm -rf $DATASTORE_PATH/$VM_NAME

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
