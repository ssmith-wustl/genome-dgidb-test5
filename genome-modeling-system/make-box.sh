#!/bin/bash -el
export PATH=/bin:$PATH # because /gsc/bin/bash sucks
rvm use 1.9.2

echo "WORKSPACE=$WORKSPACE"

if [ -s Vagrantfile ]; then
    vagrant destroy
    vagrant up
else 
    vagrant init genome_vm_base_v3
fi

vagrant halt

wget http://www.gnu.org/licenses/gpl-3.0.txt

# Export VirtualBox to an Open Virtualization Format Archive
OUT_DIR=/tmp/vbox_export
OUT_FILE=${OUT_DIR}/genome_${BUILD_ID}.ova
VM_ID=$(cat .vagrant | cut -f 3 -d : | sed 's/["}]//g')
ORIG_NAME=$(vboxmanage showvminfo $VM_ID | grep Name | head -n 1 | sed 's/Name:\ *//')

echo "OUT_FILE = $OUT_FILE"
echo "VM_ID = $VM_ID"
echo "ORIG_NAME = $ORIG_NAME"

# Rename VM because this shows up in the user's import process
vboxmanage modifyvm $VM_ID --name GMT

# Remove host-only adapter that vagrant created
vboxmanage modifyvm $VM_ID --nic2 none

# Set the VM to use Bridged Adapter
vboxmanage modifyvm $VM_ID --nic3 bridged --bridgeadapter1 eth0 --macaddress3 0800270c8dd4

# Remove the shared folders that vagrant created
vboxmanage sharedfolder remove $VM_ID --name "v-root"
vboxmanage sharedfolder remove $VM_ID --name "manifests"

# Export
mkdir -p $OUT_DIR
vboxmanage export $VM_ID --output "$OUT_FILE" --vsys 0 --product "GMT" --producturl "http://gmt.genome.wustl.edu/" --vendor "The Genome Institute at Washington University in Saint Louis" --version 1.0 --eulafile gpl-3.0.txt

# Rename back to original "vagrant" name
vboxmanage modifyvm $VM_ID --name "$ORIG_NAME"

chmod a+r "$OUT_FILE"
