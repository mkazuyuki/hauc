#!/bin/sh -ue

# (0) Parameters
DATASTORE_PATH=/vmfs/volumes/datastore1
ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-DVD-1810.iso
VM_NAME=vMA1
VM_CPU_NUM=2
VM_MEM_SIZE=4096
VM_NETWORK_NAME1="VM Network"
VM_GUEST_OS=centos7-64
VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
VM_DISK_SIZE=6g

VM_DISK_PATH=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmdk
VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

# (0) Clean up existing VM
vid=`vimd-cmd vmsvc/getallvms | grep ${VM_NAME} | awk '{print $1}'`
if [ ${vid} ]; then
	vim-cmd vmsvc/unregister $vid
fi
rm -rf $DATASTORE_PATH/$VM_NAME

# (1) Create dummy VM
VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`
echo [D] VM ID = [${VM_ID}]

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
